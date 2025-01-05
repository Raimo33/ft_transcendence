# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/26 23:51:20 by craimond          #+#    #+#              #
#    Updated: 2025/01/05 13:21:40 by craimond         ###   ########.fr        #
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
require_relative 'modules/match_handler_module'

class Server
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    @logger = CustomLogger.instance

    @auth_module = AuthModule.instance
    @connection_module = ConnectionModule.instance
    @match_handler_module = MatchHandlerModule.instance

    @jwt_public_key = @auth_module.init_public_key(@config.dig(:jwt, :public_key))
  end

  def run
    setup_signal_handlers
    host = @config.dig(:server, :host)
    port = @config.dig(:server, :port)
    fps = @config.dig(:server, :fps)

    EM.run do
      EM::WebSocket.run(host: host, port: port) do |ws|
        ws.onopen { |handshake| @connection_module.handle_open(ws, handshake) }
        ws.onmessage { |msg| @connection_module.handle_message(ws, msg) }
        ws.onclose { @connection_module.handle_close(ws) }
      rescue StandardError => e
        @connection_module.handle_exception(ws, e)
      end

      @logger.info("Server started at wss://#{host}:#{port}")

      EM.add_periodic_timer(1.0 / fps) do
        @match_handler_module.update_game_states
        @connection_module.broadcast_game_states
      end
    end
  end

  def stop
    @match_handler_module.stop_all
    EM.stop
    @logger.info("Server stopped")
  end

  def add_match(match_id, user_id1, user_id2)
    @match_handler_module.add_match(match_id, user_id1, user_id2)
  end

  def remove_match(match_id)
    @match_handler_module.remove_match(match_id)
  end

  private

  def setup_signal_handlers
    Signal.trap("INT")  { stop }
    Signal.trap("TERM") { stop }
  end
  
end
  
  