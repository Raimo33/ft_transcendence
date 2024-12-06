# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_server.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 19:30:45 by craimond          #+#    #+#              #
#    Updated: 2024/12/06 19:55:51 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative 'config_handler'
require_relative '../protos/user_api_gateway_services_pb'
require_relative 'handlers/user_api_gateway_service_handler'

class GrpcServer

  def initialize
    @config = ConfigHandler.instance.config

    @server = GRPC::RpcServer.new(
      server_host:   @config.dig(:grpc, :server, :host),
      server_port:   @config.dig(:grpc, :server, :port),
      pool_size:     @config.dig(:grpc, :server, :pool_size),
      interceptors:  [LoggerInterceptor.new, ExceptionInterceptor.new]
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
