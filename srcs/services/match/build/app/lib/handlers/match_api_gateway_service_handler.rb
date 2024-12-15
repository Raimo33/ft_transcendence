# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match_api_gateway_service_handler.rb               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 18:22:01 by craimond         ###   ########.fr        #
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
      insert_match: <<~SQL
        WITH new_match AS (
          INSERT INTO Matches (creator_id, opponent_id)
          VALUES ($1, $2)
          RETURNING id
        )
        INSERT INTO MatchPlayers (match_id, user_id)
        VALUES 
          ((SELECT id FROM new_match), $1, 1),
          ((SELECT id FROM new_match), $2, 2)
        RETURNING match_id
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

  def challenge_friend(request, call)
    opponent_id = request.opponent_id
    creator_id  = call.metadata['requester_user_id']
    check_required_fields(creator_id, opponent_id)

    #TODO controllare se l'opponent e' un amico
    #TODO controllare se l'opponent e' online
    result = @db_client.exec_prepared(:insert_match, [creator_id, opponent_id])
    match_id = result.first['match_id']

    #TODO aderire alla asyncapi specification
    payload = { match_id: match_id }
    @grpc_client.notify_clients([opponent_id], 'match_invitation', payload)

    MatchAPIGateway::Identifier.new(id: match_id)
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