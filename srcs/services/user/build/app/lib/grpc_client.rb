# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_client.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 19:25:59 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'singleton'
require_relative 'ConfigHandler'
require_relative '../protos/auth_user_services_pb'

class GrpcClient
  include Singleton
  attr_reader :stubs
  
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
      auth: AuthUser::Stub.new(@channels[:auth])
    }
  ensure
    stop
  end

  def stop
    @channels.each_value(&:close)
  end

  private

  def create_channel(addr, credentials)
    GRPC::Core::Channel.new(addr, nil, credentials)
  end

end
