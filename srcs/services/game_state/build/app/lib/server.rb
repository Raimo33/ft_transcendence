# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/26 23:51:20 by craimond          #+#    #+#              #
#    Updated: 2025/01/02 23:02:14 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'em-websocket'
require 'async'
require 'jwt'
require 'json'
require 'grpc'
require 'singleton'
require_relative 'match'
require_relative 'config_handler'
require_relative 'custom_logger'

class Server
  include Singleton

  def initialize
    @config = ConfigHandler.instance
    @logger = CustomLogger.instance
    @grpc_client = GrpcClient.instance
    @matches = Hash.new { |hash, key| hash[key] = Match.new(key) }
  end

  def run
    setup_signal_handlers
    host = @config.dig(:game_server, :host)
    port = @config.dig(:game_server, :port)
    fps = @config.dig(:game_state, :fps)

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

  def add_match(match_id)
    return false if @matches.key?(match_id)
    @matches[match_id]
  end

  def remove_match(match_id)
    return false unless @matches.key?(match_id)
    @matches.delete(match_id)
  end

  private

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
    Signal.trap('INT')  { stop }
    Signal.trap('TERM') { stop }
  end

  def handle_open(ws, handshake)
    path = handshake.path
    auth_header = handshake.headers['Authorization']
    check_authorization(auth_header)
    user_id = extract_user_id(auth_header)

    if path =~ %r{^/matches/(\w+)/updates$}
      match_id = $1
      ws.instance_variable_set(:@match_id, match_id)
      ws.instance_variable_set(:@user_id, user_id)
      raise GRPC::NotFound.new('Match not found') unless @matches.key?(match_id)
      match = @matches[match_id]
      match.add_player(user_id, ws)
      if match.state[:status] == :ongoing
        broadcast_players_info(match)
      end
      @logger.info("Player #{user_id} connected to match #{match_id}")
    else
      raise GRPC::NotFound.new('Invalid path')
    end
  end

  def handle_message(ws, msg)
    data = JSON.parse(msg, symbolize_names: true)
    send_error(ws, 400, 'Invalid message format') unless data.is_a?(Hash)
    send_error(ws, 400, 'Missing operation_id') unless data['operation_id']

    case data['operation_id']
    when 'input'
      match_id = ws.instance_variable_get(:@match_id)
      user_id = ws.instance_variable_get(:@user_id)
      data[:user_id] = user_id
      match = @matches[match_id]
      if (match.ongoing?)
        @matches[match_id].queue_input(data)
      else
        send_error(ws, 400, 'Match on hold')
      end
    else
      send_error(ws, 400, 'Invalid operation_id')
    end
  end

  def handle_close(ws)
    match_id = ws.instance_variable_get(:@match_id)
    user_id = ws.instance_variable_get(:@user_id)
    match = @matches[match_id]
    return unless match

    grace_period = @config.dig(:game_state, :disconnect_grace_period)
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
    if known_exception?(exception)
      send_error(ws, EXCEPTIONS_TO_STATUS_CODE[exception.class], exception.message)
    else
      @logger.error(exception.message)
      @logger.debug(exception.backtrace.join("\n"))
      send_error(ws, 500, 'Internal server error')
    end
    ws.close_connection
  end

  def known_exception?(exception)
    EXCEPTIONS_TO_STATUS_CODE.key?(exception.class)
  end

  def check_authorization(auth_header)
    session_token = auth_header&.split('Bearer ')&.last
    raise GRPC::Unauthenticated.new('Missing session token') unless session_token
    
    @grpc_client.validate_session_token(token: session_token)
  end

  def extract_user_id(auth_header)
    session_token = auth_header&.split('Bearer ')&.last
    payload = JWT.decode(session_token, nil, false).first
    payload['sub']
  end

  def broadcast_players_info(match)
    players = match.players
    payload = {
      operation_id: 'players_info',
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
    payload[:operation_id] = 'game_state'
    payload[:state_sequence] = match.state_sequence
    payload = JSON.generate(payload)
    match.state_sequence += 1

    async_context = Async do |task|
      task.async do
        match.players.each do |_, ws|
          ws.send(payload)
        end
      end

      if (payload[:status] == :over)
        task.async do { handle_game_over(match) }
      end
    end
    async_context.wait
  ensure
    async_context&.stop
  end

  def handle_game_over(match)
    async_context = Async do |task|
      task.async { close_connections(match) }
      task.async { save_match(match) }
    end
    async_context.wait
  ensure
    async_context&.stop
  end

  def close_connections(match)
    match.players.each do |_, ws|
      ws.close_connection
    end
  end

  def save_match(match)
    @grpc_client.save_match(
      match_id: match.id,
      winner_id: extract_winner_id(match),
      ended_at: Time.now.to_i
    )
  end

  def extract_winner_id(match)
    match.players.each do |user_id, _|
      return user_id if match.status[:health_points][user_id] > 0
    end
  end

  def send_error(ws, code, message)
    payload = {
      operation_id: 'error',
      code: code,
      message: message
    }
    payload = JSON.generate(payload)

    ws.send(payload)
  end
  
end
  
  