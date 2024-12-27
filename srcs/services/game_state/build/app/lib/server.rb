# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/26 23:51:20 by craimond          #+#    #+#              #
#    Updated: 2024/12/27 16:31:08 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

#TODO rate limiting interni per websocket (servno?)

require 'em-websocket'
require 'json'
require_relative 'match'
require_relative 'config_handler'
require_relative 'custom_logger'

class Server

  def initialize
    @config = ConfigHandler.instance
    @logger = CustomLogger.instance
    @host = @config.dig(:game_server, :host)
    @port = @config.get(:game_server, :port)
    @fps = @config.get(:game_state, :fps)
    @matches = Hash.new { |hash, key| hash[key] = Match.new(key) }
  end

  def run
    setup_signal_handlers

    EM.run do
      EM::WebSocket.run(host: @host, port: @port) do |ws|
        ws.onopen { |handshake| handle_open(ws, handshake) }
        ws.onmessage { |msg| handle_message(ws, msg) }
        ws.onclose { handle_close(ws) }
      end

      @logger.info("Server started at wss://#{@host}:#{@port}")

      EM.add_periodic_timer(1.0 / @fps) do
        update_game_states
      end
    end
  end

  def stop
    EM.stop
    @logger.info("Server stopped")
  end

  private

  def setup_signal_handlers
    Signal.trap('INT')  { stop }
    Signal.trap('TERM') { stop }
  end

  def handle_open(ws, handshake)
    path = handshake.path
    if path =~ %r{^/matches/(\w+)/updates$}
      match_id = $1
      @matches[match_id].add_player(ws)
      @logger.info("Client connected to match #{match_id}")
    else
      ws.close_connection
    end
  end

  def handle_message(ws, msg) #TODO handle wait for both players to connect #TODO handle lag compensation
    data = JSON.parse(msg)

    #TODO check input type (operationID: input)

  def handle_close(ws)

  def update_game_states
    @matches.each do |match_id, match|
      match.update
      broadcast_game_state(match)
    end
  end

  def broadcast_game_state(match)
    payload = match.state
    payload[:operationId] = 'gameState'
    payload = JSON.generate(payload)

    match.players.each do |player|
      player.send(payload)
    end
  end

  def broadcast_game_over(match)
    payload = {
      operationId: 'gameOver',
      winner: #TODO capire logica di game over, come fa il Game a segnalare il game over

    match.players.each do |player|
      player.send(payload)
    end
  end
  
end
  
  