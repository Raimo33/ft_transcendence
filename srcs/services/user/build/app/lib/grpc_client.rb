# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_client.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/26 19:37:13 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require "singleton"
require_relative "singletons/ConfigHandler"
require_relative "../proto/auth_pb"

class GrpcClient
  include Singleton
  
  def initialize
    @config   = ConfigHandler.instance.config
    @channels = {}
    @stubs    = {}

    connection_options = {
      "grpc.compression_algorithm" => "gzip"
    }

    @channels = {
      auth: create_channel(@config.dig(:grpc, :addresses, :auth), :this_channel_is_insecure, connection_options)
    }

    @stubs = {
      auth: AuthUserService::Stub.new(@channels[:auth])
    }
  rescue StandardError => e
    raise "Failed to initialize grpc client: #{e}"
  ensure
    stop
  end

  def stop
    @channels.each_value(&:close)
  end

  private

  def create_channel(addr, credentials)
    GRPC::Core::Channel.new(addr, nil, credentials)
  rescue StandardError => e
    raise "Failed to create channel to #{addr}: #{e}"
  end

end
