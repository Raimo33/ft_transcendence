# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/26 23:51:20 by craimond          #+#    #+#              #
#    Updated: 2024/12/27 18:51:28 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

#TODO rate limiting interni per websocket (servno?)

require 'em-websocket'
require 'json'
require 'grpc'
require_relative 'match'
require_relative 'config_handler'
require_relative 'custom_logger'

class Server

  def initialize
    @config = ConfigHandler.instance
    @logger = CustomLogger.instance
    @host = @config.dig(:game_server, :host)
    @port = @config.dig(:game_server, :port)
    @fps = @config.dig(:game_state, :fps)
    @disconnect_grace_period = @config.dig(:game_state, :disconnect_grace_period)
    @matches = Hash.new { |hash, key| hash[key] = Match.new(key) }
  end

  def run
    setup_signal_handlers

    EM.run do
      EM::WebSocket.run(host: @host, port: @port) do |ws|
        ws.onopen { |handshake| handle_open(ws, handshake) }
        ws.onmessage { |msg| handle_message(ws, msg) }
        ws.onclose { handle_close(ws) }
      rescue StandardError => e
        handle_error(ws, e)
      end

      @logger.info("Server started at wss://#{@host}:#{@port}")

      EM.add_periodic_timer(1.0 / @fps) do
        update_game_states
      end
    end
  end

  def stop
    @matches.each do |match_id, match|
      match.players.each do |ws|
        ws.close_connection
      end
    end
    EM.stop
    @logger.info("Server stopped")
  end

  private

  EXCEPTION_MAP = {
    GRPC::InvalidArgument => [400, 'Bad request'],
    GRPC::Unauthenticated => [401, 'Unauthorized'],
    GRPC::Unauthorized    => [403, 'Forbidden'],
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
      @matches[match_id].add_player(ws, user_id)
      @logger.info("Player #{user_id} connected to match #{match_id}")
    else
      ws.close_connection
    end
  end

  def handle_message(ws, msg) #TODO handle wait for both players to connect #TODO handle lag compensation
    data = JSON.parse(msg)
    return unless data.key?('operationId')

    case data['operationId']
    when 'input'
      match_id = ws.instance_variable_get(:@match_id)
      @matches[match_id].queue_input(data)
    else
      raise GRPC::InvalidArgument.new('Invalid operationId')
    end
  end

  def handle_close(ws)
    match_id = ws.instance_variable_get(:@match_id)
    match = @matches[match_id]
    return unless match

    match.remove_player(ws)
    EM.add_timer(@disconnect_grace_period) do
      match.surrender(ws) unless match.connected?(ws)
    end
  end

  def update_game_states #TODO handle game over (chiamare save_match di match_game_state service grpc)
    @matches.each do |match_id, match|
      match.update
      broadcast_game_state(match)
    end
  end

  def handle_error(ws, exception)
    status_code, message = EXCEPTION_MAP[exception.class]

    if status_code.nil?
      @logger.error(exception.message)
      @logger.debug(exception.backtrace.join("\n"))
      status_code = 500
      message = 'Internal server error'
    end

    send_error(ws, status_code, message)
    ws.close_connection
  end

  def check_authorization(auth_header)
    session_token = auth_header&.split('Bearer ')&.last
    raise GRPC::Unauthenticated.new('Missing session token') unless session_token
    
    @grpc_client.validate_session_token(session_token)
  end

  def extract_user_id(auth_header)
    session_token = auth_header&.split('Bearer ')&.last
    payload = JWT.decode(session_token, nil, false).first
    payload['sub']
  end

  def broadcast_game_state(match)
    payload = match.state
    payload[:operationId] = 'gameState'
    payload = JSON.generate(payload)

    match.players.each do |ws, user_id|
      ws.send(payload)
    end
  end

  def broadcast_game_over(match)
    #TODO capire logica di game over, come fa il Game a segnalare il game over
    payload[:operationId] = 'gameOver'
    payload = JSON.generate(payload)

    match.players.each do |player|
      player.send(payload)
    end
  end

  def send_error(ws, code, message)
    payload = {
      operationId: 'error',
      code: code,
      message: message
    }
    payload = JSON.generate(payload)

    ws.send(payload)
  end
  
end
  
  