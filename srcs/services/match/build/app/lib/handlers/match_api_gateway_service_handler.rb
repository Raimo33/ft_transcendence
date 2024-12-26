# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match_api_gateway_service_handler.rb               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/26 21:47:47 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require 'base64'
require_relative '../config_handler'
require_relative '../grpc_client'
require_relative '../pg_client'
require_relative '../protos/match_api_gateway_services_pb'

class MatchAPIGatewayServiceHandler < MatchAPIGateway::Service
  include EmailValidator

  def initialize
    @config       = ConfigHandler.instance.config
    @grpc_client  = GrpcClient.instance
    @pg_client    = PGClient.instance

    @prepared_statements = {
      get_user_matches: <<~SQL
        SELECT match_id
        FROM MatchPlayersChronologicalMatView
        WHERE user_id = $1 AND (started_at, match_id) < ($2, $3)
        LIMIT $4
      SQL
      is_playing: <<~SQL
        SELECT EXISTS (
          SELECT 1
          FROM MatchPlayersChronologicalMatView
          WHERE user_id = $1 AND ended_at IS NULL
        ) AS is_playing
      SQL
      are_friends: <<~SQL
        SELECT EXISTS (
          SELECT 1
          FROM Friendships
          WHERE user_id_1 = $1 AND user_id_2 = $2
        ) AS are_friends
      SQL
      get_user_status: <<~SQL
        SELECT current_status
        FROM Users
        WHERE user_id = $1
      SQL
      get_match_info: <<~SQL
        SELECT *
        FROM MatchesInfoMatView
        WHERE id = $1
      SQL
      insert_match: <<~SQL
        INSERT INTO Matches (id)
        VALUES ($1)
        RETURNING id
      SQL
      insert_match_players: <<~SQL
        INSERT INTO MatchPlayers
        VALUES ($1, $2), ($1, $3)
      SQL
      delete_match: <<~SQL
        DELETE FROM Matches
        WHERE id = $1
      SQL
    }

    prepare_statements
  end

  def ping(request, call)
    Empty.new
  end

  def get_user_matches(request, call)
    check_required_fields(request.user_id)

    cursor = decode_cursor(request.cursor) if provided?(request.cursor)
    started_at_str, match_id_str = cursor&.split(',')

    started_at = started_at_str ? Time.parse(started_at_str) : Time.now
    match_id   = match_id_str

    result = @pg_client.exec_prepared(:get_user_matches, [request.user_id, started_at, match_id, request.limit])

    match_ids = result.map { |row| row['match_id'] }      
    Common::Identifiers.new(ids: match_ids)
  end

  def start_matchmaking(request, call)
    user_id = call.metadata['requester_user_id']
    check_required_fields(user_id)

    response = @pg_client.exec_prepared(:is_playing, [user_id])
    is_playing = response.first['is_playing'] == 't'
    raise GRPC::FailedPrecondition.new("User is already playing a match") if is_playing

    @grpc_client.add_matchmaking_user(user_id)

    Empty.new
  end

  def stop_matchmaking(request, call)
    user_id = call.metadata['requester_user_id']
    check_required_fields(user_id)

    @grpc_client.remove_matchmaking_user(user_id)

    Empty.new
  end

  def challenge_friend(request, call)
    friend_id = request.friend_id
    user_id = call.metadata['requester_user_id']
    check_required_fields(user_id, friend_id)

    async_context = Async do |task|
      are_friends = task.async { friends?(user_id, friend_id) }
      is_playing  = task.async { playing?(friend_id) }
      is_online   = task.async { online?(friend_id) }

      add_invitation_task = task.async { @grpc_client.add_match_invitation(user_id, friend_id) }
    
      raise GRPC::FailedPrecondition.new("Users are not friends") unless are_friends.wait
      raise GRPC::FailedPrecondition.new("Friend is already playing a match") if is_playing.wait
      raise GRPC::FailedPrecondition.new("Friend is not online") unless is_online.wait

      add_invitation_task.wait

      @grpc_client.notify_match_invitation(from_user_id: user_id, to_user_id: friend_id)
      
      Empty.new
    rescue
      @grpc_client.remove_match_invitation(user_id, friend_id) rescue nil
      raise
    end

    async_context.wait
  ensure
    async_context&.stop
  end

  def get_match(request, call)
    match_id = request.match_id
    check_required_fields(match_id)

    response = @pg_client.exec_prepared(:get_match_info, [match_id])
    raise GRPC::NotFound.new("Match not found") if response.empty?

    row = response.first
    MatchAPIGateway::Match.new(
      id:          row['id'],
      player_ids:  pg_array_to_protobuf_array(row['player_ids']),
      status:      row['current_status'],
      started_at:  time_to_protobuf_timestamp(row['started_at']&.to_i),
      ended_at:    time_to_protobuf_timestamp(row['ended_at']&.to_i)
    )
  end

  def accept_match_invitation(request, call)
    user_id   = call.metadata['requester_user_id']
    friend_id = request.friend_id
    check_required_fields(user_id, friend_id)

    match_id = SecureRandom.uuid
  
    async_context = Async do |task|
      task.async { @grpc_client.accept_match_invitation(friend_id, user_id) }

      task.async do
        @pg_client.transaction do |tx|
          tx.exec_prepared(:insert_match, [match_id])
          tx.exec_prepared(:insert_match_players, [match_id, user_id, friend_id])
        end
      end

      task.async { @grpc_client.setup_game_state(match_id) }
      
      @grpc_client.notify_match_found(user_id, friend_id, match_id)
      
      Empty.new
    rescue
      cleanup_tasks = Async do |task|
        task.async { @grpc_client.remove_match_invitation(friend_id, user_id) }
        task.async { @pg_client.exec_prepared(:delete_match, [match_id]) }
        task.async { @grpc_client.close_game_state(match_id) }
      end
      cleanup_tasks.wait rescue nil
      raise
    end

    async_context.wait
  ensure
    async_context&.stop
  end

  def decline_match_invitation(request, call)
    user_id = call.metadata['requester_user_id']
    friend_id = request.friend_id
    check_required_fields(user_id, friend_id)

    @grpc_client.remove_match_invitation(friend_id, user_id)

    Empty.new
  end

  private

  def prepare_statements
    barrier   = Async::Barrier.new
    semaphore = Async::Semaphore.new(@config[:database][:pool][:size])

    @prepared_statements.each do |name, sql|
      barrier.async do
        semaphore.acquire do
          @pg_client.prepare(name, sql)
        end
      end
    end

    barrier.wait
  ensure
    barrier.stop
  end

  def check_required_fields(*fields)
    raise GRPC::InvalidArgument.new("Missing required fields") unless fields.all?(&method(:provided?))
  end

  def provided?(field)
    field.respond_to?(:empty?) ? !field.empty? : !field.nil?
  end

  def friends?(user_id, friend_id)
    response = @pg_client.exec_prepared(:are_friends, [user_id, friend_id])
    response.first['are_friends'] == 't'
  end

  def playing?(user_id)
    response = @pg_client.exec_prepared(:is_playing, [user_id])
    response.first['is_playing'] == 't'
  end

  def online?(user_id)
    response = @pg_client.exec_prepared(:get_user_status, [user_id])
    response.first['current_status'] == 'online'
  end

  def decode_cursor(cursor)
    Base64.decode64(cursor)
  end

  def encode_cursor(cursor)
    Base64.encode64(cursor)
  end

  def pg_array_to_protobuf_array(array_str)
   return [] if array_str.nil? || array_str.strip = '{}'
  
   array_str[1..-2].split(',')
  end

  def time_to_protobuf_timestamp(time)
    return nil unless time
    
    Google::Protobuf::Timestamp.new(seconds: time.to_i)
  end

end