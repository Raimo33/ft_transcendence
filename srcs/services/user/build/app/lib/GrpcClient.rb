# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcClient.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/16 12:22:42 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require_relative "ConfigLoader"
require_relative "../proto/auth_pb"
require_relative "ConfigurableLogger"

class GrpcClient
  attr_reader :auth
  
  def initialize
    @config = ConfigLoader.config
    @logger = ConfigurableLogger.instance.logger
    @logger.info("Initializing grpc client")

    options = {
      "grpc.compression_algorithm" => "gzip"
    }

    auth_channel  = create_channel(@config[:addresses][:auth], :this_channel_is_insecure)

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

  def create_channel(addr, credentials)
    @logger.debug("Creating channel to #{addr}")
    GRPC::Core::Channel.new(addr, nil, credentials)
  rescue StandardError => e
    raise "Failed to create channel to #{addr}: #{e}"
  end

end
