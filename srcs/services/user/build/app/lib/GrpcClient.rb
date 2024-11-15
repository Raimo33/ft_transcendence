# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcClient.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/15 15:53:55 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require_relative "ConfigLoader"
require_relative "../proto/db_gateway_pb"
require_relative "../proto/auth_pb"
require_relative "ConfigurableLogger"

class GrpcClient
  attr_reader :db_gateway, :auth
  
  def initialize
    @config = ConfigLoader.config
    @logger = ConfigurableLogger.instance.logger
    @logger.info("Initializing grpc client")

    options = {
      "grpc.compression_algorithm" => "gzip"
    }

    db_gateway_credentials  = load_credentials(@config[credentials][:certs][:db_gateway])
    auth_credentials        = load_credentials(@config[credentials][:certs][:auth])

    user_channel  = create_channel(@config[:addresses][:db_gateway], db_gateway_credentials)
    auth_channel  = create_channel(@config[:addresses][:auth], auth_credentials)

    @db_gateway = DBGatewayUserService::Stub.new(db_gateway_channel),
    @auth       = AuthUserService::Stub.new(auth_channel)

  rescue StandardError => e
    raise "Failed to initialize grpc client: #{e}"
  ensure
    close
  end

  def close
    @logger.info("Closing grpc client")
    @stubs.each do |channel|
      channel&.close if defined?(channel) && channel.respond_to?(:close)
    end
  end

  private

  def load_credentials(cert_file)
    raise "Certificate file not found: #{cert_file}" unless File.exist?(cert_file)
    @logger.debug("Loading credentials from #{cert_file}")
    GRPC::Core::ChannelCredentials.new(File.read(cert_file))
  rescue StandardError => e
    raise "Failed to load credentials from #{cert_file}: #{e}"
  end

  def create_channel(addr, credentials)
    @logger.debug("Creating channel to #{addr}")
    GRPC::Core::Channel.new(addr, nil, credentials)
  rescue StandardError => e
    raise "Failed to create channel to #{addr}: #{e}"
  end

end
