# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    game_state_match_service_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2025/01/02 13:52:36 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require_relative '../config_handler'
require_relative '../server.rb'
require_relative '../protos/game_state_match_services_pb'

class GameStateMatchServiceHandler < GameStateMatch::Service
  def initialize
    @config = ConfigHandler.instance.config
    @server = Server.instance
  end

  def ping(request, call)
    Empty.new
  end

  def setup_game_state(request, call)
    match_id = request.id
    check_required_fields(match_id)

    success = @server.add_match(match_id)
    raise GRPC::AlreadyExists.new("Match already exists") unless success

    Empty.new
  end

  def close_game_state(request, call)
    match_id = request.id
    check_required_fields(match_id)

    success = @server.remove_match(match_id)
    raise GRPC::NotFound.new("Match not found") unless success

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