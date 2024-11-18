# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcServer.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 19:30:45 by craimond          #+#    #+#              #
#    Updated: 2024/11/18 17:32:51 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require_relative "ConfigLoader"
require_relative "ConfigurableLogger"

class GrpcServer

  def initialize
    @logger = ConfigurableLogger.instance.logger
    @config = ConfigLoader.config

    @logger.info("Initializing gRPC server")
    @server = GRPC::RpcServer.new

    bind_address, port = @config[:bind].split(":")
    @server.add_http2_port("#{bind_address}:#{port}", :this_port_is_insecure)
    @server.handle(UserAPIGatewayServiceHandler)
  rescue StandardError => e
    raise "Failed to initialize gRPC server: #{e}"    
  end

  def run
    @server.run_till_terminated
  ensure
    close
  end

  def close
    @server.stop if defined?(@server)
  end

  private

end
