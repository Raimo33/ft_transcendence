# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    matchmaking_match_service_handler.rb               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/26 13:33:32 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require_relative '../config_handler'
require_relative '../memcached_client'
require_relative '../pg_client'
require_relative '../protos/matchmaking_match_services_pb'

class MatchmakingMatchServiceHandler < MatchmakingMatch::Service
  include EmailValidator

  def initialize
    @config           = ConfigHandler.instance.config
    @memcached_client = MemcachedClient.instance
    @pg_client        = PGClient.instance
  end

  def ping(request, call)
    Empty.new
  end

  def add_matchmaking_user(request, call) #TODO will retun Conflict error if user is already in the queue
    user_id = request.id
    check_required_fields(user_id)

    #TODO postgresql unlogged tables table
    
  end
  
  def remove_matchmaking_user(request, call) #TODO  will return NotFound error if user is not in the queue
    user_id = request.id
    check_required_fields(user_id)
  
    #TODO postgresql unlogged tables table 

  end

  def add_match_invitation(request, call) #TODO will return Conflict error if invitation already exists
    #TODO memcached add keys

  end

  def remove_match_invitation(request, call) #TODO will raise NotFound error if invitation does not exist
    #TODO memcached remove keys

  end

  def accept_match_invitation(request, call) #TODO will raise NotFound error if invitation does not exist
    #TODO memcached remove keys con catch error

  end

  private

  def check_required_fields(*fields)
    raise GRPC::InvalidArgument.new("Missing required fields") unless fields.all?(&method(:provided?))
  end

  def provided?(field)
    field.respond_to?(:empty?) ? !field.empty? : !field.nil?
  end

end