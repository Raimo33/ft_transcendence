# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_server.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 19:30:45 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 17:38:41 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative 'config_handler'
require_relative '../protos/game_state_match_services_pb'
require_relative 'handlers/game_state_match_handler'
require_relative 'interceptors/logger_interceptor'
require_relative 'interceptors/exception_interceptor'

class GrpcServer

  def initialize
    @config = ConfigHandler.instance.config

    @server = GRPC::RpcServer.new(
      server_host:   @config.dig(:grpc, :server, :host),
      server_port:   @config.dig(:grpc, :server, :port),
      pool_size:     @config.dig(:grpc, :server, :pool_size),
      interceptors:  [
        LoggerInterceptor.new,
        ExceptionInterceptor.new,
      ]
    )

    @services = {
      GameStateMatch::Service => GameStateMatchHandler.new
    }

    setup_handlers
  end

  def run
    @server.run_till_terminated_or_interrupted([1, "int", "TERM"])
  end

  private

  def setup_handlers
    @services.each do |service, handler|
      @server.handle(service, handler)
    end
  end

end
