# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/26 23:51:20 by craimond          #+#    #+#              #
#    Updated: 2025/01/04 17:13:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'em-websocket'
require 'async'
require 'jwt'
require 'json'
require 'singleton'
require_relative 'match'
require_relative 'shared/config_handler'
require_relative 'shared/custom_logger'
require_relative 'shared/exceptions'
require_relative 'shared/pg_client'
require_relative 'modules/auth_module'
require_relative 'modules/connection_module'

class Server
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    @logger = CustomLogger.instance
    @pg_client = PGClient.instance
    @auth_module = AuthModule.instance
    @connection_module = ConnectionModule.instance

    @jwt_public_key = @auth_module.init_public_key(@config.dig(:jwt, :public_key))
    @matches = Hash.new { |hash, key| hash[key] = Match.new(key) }
    @pg_client.prepare_statements(PREPARED_STATEMENTS)
  end

  def run
    setup_signal_handlers
    host = @config.dig(:game_server, :host)
    port = @config.dig(:game_server, :port)
    fps = @config.dig(:game_server, :fps)

    EM.run do
      EM::WebSocket.run(host: host, port: port) do |ws|
        ws.onopen { |handshake| handle_open(ws, handshake) }
        ws.onmessage { |msg| handle_message(ws, msg) }
        ws.onclose { handle_close(ws) }
      rescue StandardError => e
        handle_exception(ws, e)
      end

      @logger.info("Server started at wss://#{host}:#{port}")

      EM.add_periodic_timer(1.0 / fps) do
        update_game_states
      end
    end
  end

  def stop
    @matches.each do |_, match|
      match.players.each do |ws|
        ws.close_connection
      end
    end
    EM.stop
    @logger.info("Server stopped")
  end

  def add_match(match_id, user_id1, user_id2)
    return false if @matches.key?(match_id)
    match = Match.new(match_id, user_id1, user_id2)
    @matches[match_id] = match

    EM.add_timer(@config.dig(:game_server, :match_timeout)) do
      return false unless @matches.key?(match_id)
      loser_id = match.player_connected?(user_id1) ? user_id2 : user_id1
      match.surrender_player(loser_id)
    end
  end

  def remove_match(match_id)
    return false unless @matches.key?(match_id)
    @matches.delete(match_id)
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

  EXCEPTIONS_TO_STATUS_CODE = {
    GRPC::InvalidArgument    => 400,
    GRPC::OutOfRange         => 400,
    GRPC::Unauthenticated    => 401,
    GRPC::PermissionDenied   => 403,
    GRPC::NotFound           => 404,
    GRPC::AlreadyExists      => 409,
    GRPC::Aborted            => 409,
    GRPC::FailedPrecondition => 412,
    GRPC::ResourceExhausted  => 429,
    GRPC::Cancelled          => 499,
    GRPC::Internal           => 500,
    GRPC::DataLoss           => 500,
    GRPC::Unimplemented      => 501,
    GRPC::Unavailable        => 503,
  }.freeze

  def setup_signal_handlers
    Signal.trap("INT")  { stop }
    Signal.trap("TERM") { stop }
  end

  def handle_open(ws, handshake)
    path = handshake.path
    auth_header = handshake.headers["Authorization"]
    user_id = @auth_module.check_authorization(auth_header)

    if path =~ %r{^/matches/(\w+)/updates$}
      match_id = $1
      ws.instance_variable_set(:@match_id, match_id)
      ws.instance_variable_set(:@user_id, user_id)
      raise NotFound.new("Match not found") unless @matches.key?(match_id)
      match = @matches[match_id]
      match.add_player(user_id, ws)
      if match.state[:status] == :ongoing
        broadcast_players_info(match)
      end
      @logger.info("Player #{user_id} connected to match #{match_id}")
    else
      raise NotFound.new("Match not found")
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
      match = @matches[match_id]
      if (match.ongoing?)
        @matches[match_id].queue_input(data)
      else
        send_error(ws, 400, "Match on hold")
      end
    else
      send_error(ws, 400, "Invalid operation_id")
    end
  end

  def handle_close(ws)
    match_id = ws.instance_variable_get(:@match_id)
    user_id = ws.instance_variable_get(:@user_id)
    match = @matches[match_id]
    return unless match

    grace_period = @config.dig(:game_server, :match_timeout)
    match.pause_player(user_id)
    EM.add_timer(grace_period) do
      match.surrender_player(user_id) if (match.state[:status] == :waiting)
      broadcast_game_state
    end
  end

  def update_game_states
    @matches.each do |_, match|
      match.update
      broadcast_game_state
    end
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

  def broadcast_players_info(match)
    players = match.players
    payload = {
      operation_id: "players_info",
      player_0_id: players.keys[0],
      player_1_id: players.keys[1],
    }
    payload = JSON.generate(payload)

    players.each do |_, ws|
      ws.send(payload)
    end
  end

  def broadcast_game_state(match)
    payload = match.state
    payload[:operation_id] = "game_state"
    payload[:state_sequence] = match.state_sequence
    payload = JSON.generate(payload)
    match.state_sequence += 1

    async_context = Async do |task|
      task.async do
        match.players.each do |_, ws|
          ws.send(payload)
        end
      end

      if (payload[:status] == :ended)
        task.async do { handle_game_over(match) }
      end
    end
    async_context.wait
  ensure
    async_context&.stop
  end

  def handle_game_over(match)
    Async do |task|
      task.async { close_connections(match) }
      task.async { save_match(match) }
    end
    @matches.delete(match.id)
  end

  def close_connections(match)
    match.players.each do |_, ws|
      ws.close_connection
    end
  end

  def save_match(match)
    winner_id = extract_winner_id(match)
    @pg_client.transaction do |tx|
      tx.exec_prepared("update_match", [match.id, match.status, Time.now])
      tx.exec_prepared("set_winner", [match.id, winner_id])
    end
  end

  def extract_winner_id(match)
    match.players.each do |user_id, _|
      return user_id if match.status[:health_points][user_id] > 0
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
  
end
  
  