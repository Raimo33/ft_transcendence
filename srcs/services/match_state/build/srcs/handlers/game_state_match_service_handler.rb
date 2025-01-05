# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match_state_match_service_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2025/01/05 01:18:55 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require_relative '../config_handler'
require_relative '../server.rb'
require_relative '../protos/match_state_app_services_pb'

class MatchStateMatchServiceHandler < MatchStateMatch::Service
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