# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcServer.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 19:30:45 by craimond          #+#    #+#              #
#    Updated: 2024/11/09 20:09:51 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require_relative "./modules/ConfigLoader"
require_relative "./modules/Logger"

class GrpcServer
  include ConfigLoader
  include Logger

  def initialize
    @logger = Logger.logger
    @config = ConfigLoader.config

    @logger.info("Initializing gRPC server...")
    @server = GRPC::RpcServer.new
    @server.add_http2_port("#{@config[:host]}:#{@config[:port]}", load_ssl_context(@config[:user_key], @config[:user_cert]))
    @server.handle(UserServiceHandler)
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
