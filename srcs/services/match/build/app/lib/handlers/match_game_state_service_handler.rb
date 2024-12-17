# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match_game_state_service_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/17 19:20:20 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require_relative '../config_handler'
require_relative '../grpc_client'
require_relative '../db_client'
require_relative '../protos/match_game_state_services_pb'

class MatchGameStateServiceHandler < MatchGameState::Service
  include EmailValidator

  def initialize
    @config       = ConfigHandler.instance.config
    @grpc_client  = GrpcClient.instance
    @db_client    = DBClient.instance

    @prepared_statements = {
      update_match: <<~SQL
        UPDATE Matches
        SET status = $2, ended_at = $3
        WHERE id = $1
      SQL
      set_winner: <<~SQL
        UPDATE MatchPlayers
        SET position = CASE
          WHEN user_id = $2 THEN 1
          ELSE 2
        END
        WHERE match_id = $1
      SQL
    }

    prepare_statements
  end

  def ping(request, call)
    Empty.new
  end

  def save_match(request, call)
    match_id = request.match_id
    winner_id = request.winner_id
    ended_at = request.ended_at
    check_required_fields(match_id, winner_id, ended_at)

    @db_client.transaction do |tx|
      tx.exec_prepared("update_match", [match_id, 'ended', ended_at])
      tx.exec_prepared("set_winner", [match_id, winner_id])
    end

    Empty.new
  end
  
  private

  def prepare_statements
    barrier   = Async::Barrier.new
    semaphore = Async::Semaphore.new(@config[:database][:pool][:size])

    @prepared_statements.each do |name, sql|
      barrier.async do
        semaphore.acquire do
          @db_client.prepare(name, sql)
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