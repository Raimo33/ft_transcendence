# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    matchmaking_match_service_handler.rb               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/25 20:19:35 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require_relative '../config_handler'
require_relative '../memcached_client'
require_relative '../protos/matchmaking_match_services_pb'

class MatchmakingMatchServiceHandler < MatchmakingMatch::Service
  include EmailValidator

  def initialize
    @config           = ConfigHandler.instance.config
    @grpc_client      = GrpcClient.instance
    @memcached_client = MemcachedClient.instance
  end

  def ping(request, call)
    Empty.new
  end

  def add_matchmaking_user(request, call)
    user_id = request.id
    check_required_fields(user_id)

    #TODO implement
  
  def remove_matchmaking_user(request, call)

  def add_match_invitation(request, call)

  def remove_match_invitation(request, call)

  def accept_match_invitation(request, call)

  private

  def check_required_fields(*fields)
    raise GRPC::InvalidArgument.new("Missing required fields") unless fields.all?(&method(:provided?))
  end

  def provided?(field)
    field.respond_to?(:empty?) ? !field.empty? : !field.nil?
  end

end