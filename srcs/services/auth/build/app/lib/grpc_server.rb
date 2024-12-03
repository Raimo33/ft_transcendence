# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_server.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 19:30:45 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 12:36:40 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative 'config_handler'
require_relative '../protos/auth_user_services_pb'
require_relative 'handlers/auth_user_service_handler'

class GrpcServer

  def initialize
    @config   = ConfigHandler.instance.config

    @server   = GRPC::RpcServer.new(
      server_host:  @config.dig(:grpc, :server, :host),
      server_port:  @config.dig(:grpc, :server, :port),
      pool_size:    @config.dig(:grpc, :server, :pool_size),
      interceptors: [LoggerInterceptor.new, ExceptionInterceptor.new]
    )

    @services = {
      AuthUser::Service => AuthUserServiceHandler.new,
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
