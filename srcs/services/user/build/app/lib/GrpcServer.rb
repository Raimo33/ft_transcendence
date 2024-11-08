# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcServer.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 19:30:45 by craimond          #+#    #+#              #
#    Updated: 2024/11/08 20:01:24 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative './modules/ConfigLoader'
require_relative './modules/Logger'

class GrpcServer
  include ConfigLoader
  include Logger

  def initialize
    @config = ConfigLoader.config
    @server = GRPC::RpcServer.new
    @server.add_http2_port("#{@config[:host]}:#{@config[:port]}", load_server_credentials(@config[:user_key], @config[:user_cert]))
    @server.handle(UserServiceHandler)
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

  def load_server_credentials(cert_path, key_path)
    cert = File.read(cert_path)
    key = File.read(key_path)

    GRPC::Core::ServerCredentials.new(nil, [{ private_key: key, cert_chain: cert }], false)
  rescue StandardError => e
    raise "Failed to load credentials from #{cert_path} and #{key_path}: #{e.message}"
  end

end
