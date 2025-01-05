# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match_state_app_service_handler.rb                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/05 17:29:28 by craimond          #+#    #+#              #
#    Updated: 2025/01/05 17:33:47 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'eventmachine'
require_relative '../config_handler'
require_relative '../server.rb'
require_relative '../protos/match_state_app_services_pb'

class MatchStateAppServiceHandler < MatchStateApp::Service
  def initialize
    @config = ConfigHandler.instance.config
    @server = Server.instance
  end

  def ping(request, call)
    Empty.new
  end

  def setup_match_state(request, call)
    match_id, user_id1, user_id2 = request.match_id, request.user_id1, request.user_id2
    check_required_fields(match_id, user_id1, user_id2)

    @server.add_match(match_id, user_id1, user_id2)

    Empty.new
  end

  def close_match_state(request, call)
    match_id = request.match_id
    check_required_fields(match_id)

    @server.remove_match(match_id)

    Empty.new
  end

  private

  def check_required_fields(*fields)
    fields.each do |field|
      raise BadRequest.new("Missing required field: #{field}") if field.nil? || field.empty?
    end
  end

end