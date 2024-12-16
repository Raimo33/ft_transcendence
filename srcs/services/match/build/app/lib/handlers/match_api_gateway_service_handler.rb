# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match_api_gateway_service_handler.rb               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/16 19:46:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require 'base64'
require_relative '../config_handler'
require_relative '../grpc_client'
require_relative '../db_client'

class MatchAPIGatewayServiceHandler < MatchAPIGateway::Service
  include EmailValidator

  def initialize
    @config       = ConfigHandler.instance.config
    @grpc_client  = GrpcClient.instance
    @db_client    = DBClient.instance

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
        FROM Matches
        WHERE match_id = $1
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

    result = @db_client.exec_prepared(:get_user_matches, [request.user_id, started_at, match_id, request.limit])

    match_ids = result.map { |row| row['match_id'] }      
    MatchAPIGateway::Identifiers.new(ids: match_ids)
  end

  def start_matchmaking(request, call)
    user_id = call.metadata['requester_user_id']
    check_required_fields(user_id)

    response = @db_client.exec_prepared(:is_playing, [user_id])
    is_playing = response.first['is_playing'] == 't'
    raise GRPC::FailedPrecondition.new("User is already playing a match") if is_playing

    @grpc_client.add_matchmaking_user(user_id) #TODO will retun Conflict error if user is already in the queue

    Empty.new
  end

  def stop_matchmaking(request, call)
    user_id = call.metadata['requester_user_id']
    check_required_fields(user_id)

    @grpc_client.remove_matchmaking_user(user_id) #TODO will return Conflict error if user is not in the queue

    Empty.new
  end

  def challenge_friend(request, call)
    friend_id = request.friend_id
    user_id = call.metadata['requester_user_id']
    check_required_fields(user_id, friend_id)

    async_context = Async do |task|
      are_friends_task = task.async do
        response = @db_client.exec_prepared(:are_friends, [user_id, friend_id])
        response.first['are_friends'] == 't'
      end
    
      is_playing_task = task.async do
        response = @db_client.exec_prepared(:is_playing, [friend_id])
        response.first['is_playing'] == 't'
      end

      is_online_task = task.async do
        response = @db_client.exec_prepared(:get_user_status, [friend_id])
        response.first['current_status'] == 'online'
      end
      
      raise GRPC::FailedPrecondition.new("Users are not friends") unless are_friends_task.wait
      raise GRPC::FailedPrecondition.new("Friend is already playing a match") if is_playing_task.wait
      raise GRPC::FailedPrecondition.new("Friend is not online") unless is_online_task.wait
    end

    notification_type = 'matchInvitation'
    notification_payload = { from_user: user_id }
    @grpc_client.notify_clients([friend_id], notification_type, notification_payload)

    Empty.new
  ensure
    async_context&.stop
  end

  def get_match(request, call)
    match_id = request.match_id
    check_required_fields(match_id)

    response = @db_client.exec_prepared(:get_match_info, [match_id])
    raise GRPC::NotFound.new("Match not found") if response.empty?

    row = response.first
    MatchAPIGateway::Match.new(
      id:         row['id'],
      player_ids: row['player_ids'],
      #TODO implement
  end

  def accept_match_invitation(request, call)

    @grpc_client.start_game_state_management(match_id)

  private

  def check_required_fields(*fields)
    raise GRPC::InvalidArgument.new("Missing required fields") unless fields.all?(&method(:provided?))
  end

  def provided?(field)
    field.respond_to?(:empty?) ? !field.empty? : !field.nil?
  end

  def decode_cursor(cursor)
    Base64.decode64(cursor)
  end

  def encode_cursor(cursor)
    Base64.encode64(cursor)
  end

end