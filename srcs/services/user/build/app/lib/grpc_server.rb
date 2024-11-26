# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_server.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 19:30:45 by craimond          #+#    #+#              #
#    Updated: 2024/11/25 17:49:32 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require_relative "singletons/ConfigHandler"

class GrpcServer

  def initialize
    @config = ConfigHandler.instance.config
    @server = GRPC::RpcServer.new(
      pool_size: @config.fetch(:pool_size, 10),
      #TODO controllare tutte le possibili flag 

    )

    bind_address, port = @config[:bind].split(":")
    @server.add_http2_port("#{bind_address}:#{port}", :this_port_is_insecure)
    @server.handle(UserAPIGatewayServiceHandler.new)
  rescue StandardError => e
    raise "Failed to initialize gRPC server: #{e}"    
  end

  def run
    @server.run_till_terminated
  ensure
    stop
  end

  def stop
    @server.stop if defined?(@server)
  end

  private

end
