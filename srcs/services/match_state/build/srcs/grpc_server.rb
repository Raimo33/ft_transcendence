# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_server.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 19:30:45 by craimond          #+#    #+#              #
#    Updated: 2025/01/05 18:10:46 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative 'config_handler'
require_relative '../protos/match_state_app_services_pb'
require_relative 'handlers/match_state_app_handler'
require_relative 'middlewares/server/logger_interceptor'
require_relative 'middlewares/server/exception_interceptor'

class GrpcServer

  def initialize
    @config = ConfigHandler.instance.config
    @logger = CustomLogger.instance.logger

    @server = GRPC::RpcServer.new(
      server_host: @config.dig(:grpc, :server, :host),
      server_port: @config.dig(:grpc, :server, :port),
      pool_size:   @config.dig(:grpc, :server, :pool_size),
      interceptors:  [
        LoggerInterceptor.new,
        ExceptionInterceptor.new,
      ]
      logger: @logger
    )

    @services = {
      MatchStateApp::Service => MatchStateAppHandler.new
    }

    setup_handlers
  end

  def run
    @server.run_till_terminated_or_interrupted([1, "int", "TERM"])
  end

  def stop
    @server.stop
    @logger.info('gRPC server stopped')
  end

  private

  def setup_handlers
    @services.each do |service, handler|
      @server.handle(service, handler)
    end
  end

end
