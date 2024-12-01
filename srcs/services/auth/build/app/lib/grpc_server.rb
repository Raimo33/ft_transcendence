# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_server.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 19:30:45 by craimond          #+#    #+#              #
<<<<<<< Updated upstream
#    Updated: 2024/12/01 14:56:49 by craimond         ###   ########.fr        #
=======
#    Updated: 2024/11/28 16:49:06 by craimond         ###   ########.fr        #
>>>>>>> Stashed changes
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative 'config_handler'
require_relative '../middleware/service_handler_middleware'
require_relative '../proto/auth_user_services_pb'

class GrpcServer

  def initialize
    @config   = ConfigHandler.instance.config
    @services = ServiceRegistry.instance.services
    @server   = GRPC::RpcServer.new(
      server_host:  @config.dig(:grpc, :server, :host),
      server_port:  @config.dig(:grpc, :server, :port),
      pool_size:    @config.dig(:grpc, :server, :pool_size),
    )
    middleware_registry = MiddlewareRegistry.instance
    middleware_registry.use RequestLogger
    middleware_registry.use ExceptionHandler

    pair_handlers
  end

  def run
    @server.run_till_terminated_or_interrupted([1, "int", "TERM"])
  end

  private

  def pair_handlers
    @services.each do |service, handler|
      @server.handle(service, wrapped_handler)
    end
  end

end
