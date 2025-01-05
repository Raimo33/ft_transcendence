# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    connection_module.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/05 00:25:52 by craimond          #+#    #+#              #
#    Updated: 2025/01/05 16:10:15 by craimond         ###   ########.fr        #
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
require_relative '../shared/pg_client'
require_relative '../shared/exceptions'

class ConnectionModule
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    @logger = CustomLogger.instance
    @pg_client = PGClient.instance

    @auth_module = AuthModule.instance
    @match_handler_module = MatchHandlerModule.instance

    @pg_client.prepare_statements(PREPARED_STATEMENTS)
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

  def broadcast_match_states
    @match_handler_module.matches.each do |_, match|
      payload = match.state
      ended = payload[:status] == :ended 
      payload[:operation_id] = "match_state"
      payload = JSON.generate(payload)

      match.players.each do |_, ws|
        ws.send(payload)
      end

      handle_match_over(match) if ended
    end
  end

  def broadcast_players_info(match_id)
    match = @match_handler_module.matches[match_id]
    players = match.players
    payload = {
      operation_id: "players_info",
      players: players.keys
    }
    payload = JSON.generate(payload)

    players.each do |_, ws|
      ws.send(payload)
    end
  end

  def send_error(ws, code, message)
    payload = {
      operation_id: "error",
      code: code,
      message: message
    }
    payload = JSON.generate(payload)

    ws.send(payload)
  end

  private

  PREPARED_STATEMENTS = {
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
  }.freeze

  def handle_match_over(match)
    operations = [
      -> { close_connections(match) },
      -> { save_match(match) }
    ]
  
    cleanup = EM::MultipleCallback.new(operations.size)
    cleanup.callback do
      EM.next_tick { @matches.delete(match.id) }
    end
  
    operations.each do |op|
      EM.defer do
        op.call
        cleanup.call
      end
    end
  end

  def close_connections(match)
    match.players.each do |_, ws|
      ws.close_connection
    end
  end

  def save_match(match)
    state = match.state
    ended_at = state[:timestamp]
    winner_id = extract_winner_id(state)

    @pg_client.transaction do |tx|
      tx.exec_prepared("update_match", [match.id, :ended, ended_at])
      tx.exec_prepared("set_winner", [match.id, winner_id])
    end
  end

  def extract_winner_id(state)
    health_points = state[:health_points]
    health_points.each_with_index do |hp, idx|
      return state[:players][idx] if hp > 0
    end
  end

end
