# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_server.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 19:30:45 by craimond          #+#    #+#              #
#    Updated: 2024/11/26 19:36:27 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require_relative "singletons/ConfigHandler"

class GrpcServer

  def initialize
    @config   = ConfigHandler.instance.config
    @services = ServiceRegistry.instance.services
    @server   = GRPC::RpcServer.new(
      server_host:          @config.dig(:grpc, :server, :host),
      server_port:          @config.dig(:grpc, :server, :port),
      pool_size:            @config.dig(:grpc, :server, :pool_size),
    )
    middleware_registry = MiddlewareRegistry.instance
    middleware_registry.use RequestLogger
    middleware_registry.use ExceptionHandler

    pair_handlers
  rescue StandardError => e
    raise "Failed to initialize gRPC server: #{e}"
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
