# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    game_state_match_service_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/26 23:44:17 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require_relative '../config_handler'
require_relative '../grpc_client'
require_relative '../protos/game_state_match_services_pb'

class GameStateMatchServiceHandler < GameStateMatch::Service
  def initialize
    @config       = ConfigHandler.instance.config
    @grpc_client  = GrpcClient.instance
  end

  def ping(request, call)
    Empty.new
  end

  def setup_game_state(request, call) //TODO will return Conflict if user already playing (websocket already existent)
    match_id = request.id
    check_required_fields(match_id)

    #TODO setup websocket

    ActionCable.server.broadcast("#{match_id}", @matches[match_id])
    Empty.new
  end

  def close_game_state(request, call)  //TODO will return Conflict if user not playing (websocket not existent)
    match_id = request.id
    check_required_fields(match_id)

    #TODO close websocket

    Empty.new
  end

  private

  def check_required_fields(*fields)
    raise GRPC::InvalidArgument.new("Missing required fields") unless fields.all?(&method(:provided?))
  end

  def provided?(field)
    field.respond_to?(:empty?) ? !field.empty? : !field.nil?
  end

end