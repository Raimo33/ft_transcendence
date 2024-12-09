# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_server.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 19:30:45 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 15:55:15 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative 'config_handler'
require_relative '../protos/user_api_gateway_services_pb'
require_relative 'handlers/user_api_gateway_service_handler'
require_relative 'interceptors/logger_interceptor'
require_relative 'interceptors/exception_interceptor'
require_relative 'interceptors/request_context_interceptor'

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
        RequestContextInterceptor.new
      ]
    )

    @services = {
      UserAPIGateway::Service => UserAPIGatewayServiceHandler.new,
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
