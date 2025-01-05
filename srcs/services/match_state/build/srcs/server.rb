# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/26 23:51:20 by craimond          #+#    #+#              #
#    Updated: 2025/01/05 18:12:14 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'singleton'
require 'em-websocket'
require_relative 'shared/config_handler'
require_relative 'shared/custom_logger'
require_relative 'modules/connection_module'
require_relative 'modules/match_handler_module'
require_relative 'shared/pg_client'

class Server
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    @logger = CustomLogger.instance
    @pg_client = PGClient.instance

    @connection_module = ConnectionModule.instance
    @match_handler_module = MatchHandlerModule.instance
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
        @match_handler_module.update_match_states
        @connection_module.broadcast_match_states
      end
    end
  end

  def stop
    @connection_module.close_all_connections
    @pg_client.stop
    @match_handler_module.clear_matches
    @logger.info('Server stopped')
  end

  def add_match(match_id, user_id1, user_id2)
    @match_handler_module.add_match(match_id, user_id1, user_id2)
  end

  def remove_match(match_id)
    @match_handler_module.remove_match(match_id)
  end
  
end
  
  