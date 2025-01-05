# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    connection_module.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/05 00:25:52 by craimond          #+#    #+#              #
#    Updated: 2025/01/05 01:09:56 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'singleton'
require 'eventmachine'
require 'jwt'
require 'json'
require_relative 'auth_module'
require_relative 'match_handler_module'
require_relative '../shared/config_handler'
require_relative '../shared/custom_logger'
require_relative '../shared/exceptions'

class ConnectionModule
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    @logger = CustomLogger.instance

    @auth_module = AuthModule.instance
    @match_handler_module = MatchHandlerModule.instance
  end

  def handle_open(ws, handshake)
    path = handshake.path
    auth_header = handshake.headers["Authorization"]
    user_id = @auth_module.check_authorization(auth_header)

    if path =~ %r{^/matches/(\w+)/updates$}
      match_id = $1
      ws.instance_variable_set(:@match_id, match_id)
      ws.instance_variable_set(:@user_id, user_id)
      @match_handler_module.add_player(match_id, user_id, ws)
      broadcast_players_info(match_id)
      @logger.info("Player #{user_id} connected to match #{match_id}")
    else
      raise NotFound.new("Invalid path")
    end
  end

  def handle_message(ws, msg)
    data = JSON.parse(msg, symbolize_names: true)
    send_error(ws, 400, "Invalid message format") unless data.is_a?(Hash)
    send_error(ws, 400, "Missing operation_id") unless data["operation_id"]

    case data[:operation_id]
    when "input"
      match_id = ws.instance_variable_get(:@match_id)
      user_id = ws.instance_variable_get(:@user_id)
      data[:user_id] = user_id
      @match_handler_module.add_input(match_id, data)
    else
      send_error(ws, 400, "Invalid operation_id")
    end
  end

  def handle_close(ws)
    match_id = ws.instance_variable_get(:@match_id)
    user_id = ws.instance_variable_get(:@user_id)
    @match_handler_module.remove_player(match_id, user_id)
  end

  def handle_exception(ws, exception)    
    if (exception.is_a?(HttpError))
      send_error(ws, exception.status, exception.message)
    else
      @logger.error(exception)
      @logger.debug(exception.backtrace.join("\n"))
      send_error(ws, 500, "Internal server error")
    end
    ws.close_connection
  end

  def broadcast_game_states #TODO scorre tutti i match e invia lo stato a tutti i giocatori
  #   payload = match.state
  #   payload[:operation_id] = "game_state"
  #   payload = JSON.generate(payload)

  #   async_context = Async do |task|
  #     task.async do
  #       match.players.each do |_, ws|
  #         ws.send(payload)
  #       end
  #     end

  #     if (payload[:status] == :ended)
  #       task.async do { handle_game_over(match) }
  #     end
  #   end
  #   async_context.wait
  # ensure
  #   async_context&.stop
  # end

  def broadcast_players_info(match_id) #TODO invia a tutti i giocatori del match le informazioni sui giocatori
    # players = match.players
    # payload = {
    #   operation_id: "players_info",
    #   player_1_id: players.keys[0],
    #   player_2_id: players.keys[1],
    # }
    # payload = JSON.generate(payload)

    # players.each do |_, ws|
    #   ws.send(payload)
    # end

    # def handle_game_over(match)
    #   Async do |task|
    #     task.async { close_connections(match) }
    #     task.async { save_match(match) }
    #   end
    #   @matches.delete(match.id)
    # end
  
    # def close_connections(match)
    #   match.players.each do |_, ws|
    #     ws.close_connection
    #   end
    # end
  
    # def save_match(match)
    #   winner_id = extract_winner_id(match)
    #   @pg_client.transaction do |tx|
    #     tx.exec_prepared("update_match", [match.id, match.status, Time.now])
    #     tx.exec_prepared("set_winner", [match.id, winner_id])
    #   end
    # end
  
    # def extract_winner_id(match)
    #   match.players.each do |user_id, _|
    #     return user_id if match.status[:health_points][user_id] > 0
    #   end
    # end
  
    # def send_error(ws, code, message)
    #   payload = {
    #     operation_id: "error",
    #     code: code,
    #     message: message
    #   }
    #   payload = JSON.generate(payload)
  
    #   ws.send(payload)
    # end
