# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/26 23:51:20 by craimond          #+#    #+#              #
#    Updated: 2024/12/27 00:43:12 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

#TODO rate limiting interni per websocket (servno?)
#EventMachine!!

require 'em-websocket'
require_relative 'config_handler'
require_relative 'custom_logger'

class Server

  def initialize
    @config = ConfigHandler.instance
    @logger = CustomLogger.instance
    @host = @config.dig(:game_server, :host)
    @port = @config.get(:game_server, :port)
    @matches = Hash.new
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
      @matches[match_id] << ws
      @logger.info("Client connected to match #{match_id}")
    else
      ws.close_connection
    end
  end

  def handle_message(ws, msg) #TODO handle wait for both players to connect

  def handle_close(ws)
  

end
  
  