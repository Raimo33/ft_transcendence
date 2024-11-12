# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcServer.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 19:30:45 by craimond          #+#    #+#              #
#    Updated: 2024/11/12 14:43:42 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require_relative "ConfigLoader"
require_relative "ConfigurableLogger"

class GrpcServer

  def initialize
    @logger = ConfigurableLogger.instance.logger
    @config = ConfigLoader.config

    @logger.info("Initializing gRPC server...")
    @server = GRPC::RpcServer.new

    bind_address, port = @config[:bind].split(":")
    @server.add_http2_port("#{bind_address}:#{port}", load_ssl_context(@config[:credentials][:keys][:user], @config[:credentials][:certs][:user]))
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

  def load_ssl_context(ssl_key, ssl_cert)
    @logger.info("Loading SSL context...")
    cert = File.read(cert_path)
    key = File.read(key_path)

    GRPC::Core::ServerCredentials.new(nil, [{ private_key: key, cert_chain: cert }], false)
  rescue StandardError => e
    raise "Failed to load SSL context: #{e}"
  end

end
