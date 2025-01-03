# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match_matchmaking_service_handler.rb               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2025/01/02 23:20:23 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require_relative '../config_handler'
require_relative '../grpc_client'
require_relative '../pg_client'
require_relative '../protos/match_matchmaking_services_pb'

class MatchMatchmakingServiceHandler < MatchMatchmaking::Service

  def initialize
    @config       = ConfigHandler.instance.config
    @grpc_client  = GrpcClient.instance
    @pg_client    = PGClient.instance

    @prepared_statements = {
      insert_match: <<~SQL
        INSERT INTO Matches (id)
        VALUES ($1)
      SQL
      insert_match_players: <<~SQL
        INSERT INTO MatchPlayers
        VALUES ($1, $2), ($1, $3)
      SQL
    }

    prepare_statements
  end

  def ping(request, call)
    Empty.new
  end

  def match_found(request, call)
    user_id_1 = requester_user_id_1
    user_id_2 = request.user_id_2
    check_required_fields(player_1, player_2)

    match_id = SecureRandom.uuid
    @pg_client.transaction do |tx|
      tx.exec_prepared('insert_match', [request.match_id])
      tx.exec_prepared('insert_match_players', [match_id, user_id_1, user_id_2])
    end

    @grpc_client.notify_match_found(user_id_1, user_id_2, match_id)

    Empty.new
  end

  private

  def prepare_statements
    barrier   = Async::Barrier.new
    semaphore = Async::Semaphore.new(@config.dig(:postgresql, :pool, :size))

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

end