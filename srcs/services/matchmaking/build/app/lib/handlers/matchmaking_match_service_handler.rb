# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    matchmaking_match_service_handler.rb               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/26 23:19:13 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require_relative '../config_handler'
require_relative '../memcached_client'
require_relative '../pg_client'
require_relative '../protos/matchmaking_match_services_pb'

class MatchmakingMatchServiceHandler < MatchmakingMatch::Service

  def initialize
    @config           = ConfigHandler.instance.config
    @memcached_client = MemcachedClient.instance
    @pg_client        = PGClient.instance

    @prepared_statements = {
      add_matchmaking_user: <<~SQL
        INSERT INTO MatchmakingPool (user_id)
        VALUES ($1)
      SQL
      remove_matchmaking_user: <<~SQL
        DELETE FROM MatchmakingPool
        WHERE user_id = $1
      SQL
    }

    prepare_statements
  end

  def ping(request, call)
    Empty.new
  end

  def add_matchmaking_user(request, call)
    user_id = request.id
    check_required_fields(user_id)

    @pg_client.exec_prepared('add_matchmaking_user', [user_id])
    Empty.new
  end
  
  def remove_matchmaking_user(request, call)
    user_id = request.id
    check_required_fields(user_id)
  
    @pg_client.exec_prepared('remove_matchmaking_user', [user_id])
    Empty.new
  end

  def add_match_invitation(request, call)
    check_required_fields(request.from_user_id, request.to_user_id)

    user_ids = [equest.from_user_id, request.to_user_id].sort
    succecss = @memcached_client.add(":match_invitation#{user_ids[0]}:#{user_ids[1]}")
    raise GRPC::AlreadyExists.new("Match invitation already exists") unless success
    Empty.new
  end

  def remove_match_invitation(request, call)
    check_required_fields(request.from_user_id, request.to_user_id)

    user_ids = [equest.from_user_id, request.to_user_id].sort
    success = @memcached_client.delete(":match_invitation#{user_ids[0]}:#{user_ids[1]}")
    raise GRPC::NotFound.new("Match invitation not found") unless success
    Empty.new
  end

  def accept_match_invitation(request, call)
    check_required_fields(request.from_user_id, request.to_user_id)

    user_ids = [equest.from_user_id, request.to_user_id].sort
    success = @memcached_client.delete(":match_invitation#{user_ids[0]}:#{user_ids[1]}")
    raise GRPC::NotFound.new("Match invitation not found") unless success

    @grpc_client.match_found(user_id_1: user_ids[0], user_id_2: user_ids[1])
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

end