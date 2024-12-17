# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match_matchmaking_service_handler.rb               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/17 19:22:18 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require_relative '../config_handler'
require_relative '../grpc_client'
require_relative '../db_client'
require_relative '../protos/match_matchmaking_services_pb'

class MatchMatchmakingServiceHandler < MatchMatchmaking::Service
  include EmailValidator

  def initialize
    @config       = ConfigHandler.instance.config
    @grpc_client  = GrpcClient.instance
    @db_client    = DBClient.instance

    @prepared_statements = {
      
    }

    prepare_statements
  end

  def ping(request, call)
    Empty.new
  end

  def match_found(request, call)
    #TODO creera l'oggetto match e inviera' la notification_payload a tutti i giocatori
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