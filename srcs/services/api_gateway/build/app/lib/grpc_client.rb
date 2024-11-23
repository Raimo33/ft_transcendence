# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_client.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:37:07 by craimond          #+#    #+#              #
#    Updated: 2024/11/23 16:19:35 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'yaml'
require 'singleton'

class GrpcClient
  include Singleton

  attr_reader :stubs

  def initialize(config)
    @config = config
    setup_connections
  end

  private

  def setup_connections
    @channels = {
      user:         GRPC::Core::Channel.new(@config.dig('grpc', 'addresses', 'user'), nil),
      match:        GRPC::Core::Channel.new(@config.dig('grpc', 'addresses', 'match'), nil),
      tournament:   GRPC::Core::Channel.new(@config.dig('grpc', 'addresses', 'tournament'), nil),
      auth:         GRPC::Core::Channel.new(@config.dig('grpc', 'addresses', 'auth'), nil)
    }
    
    @stubs = {
      user:       User::Stub.new(@channels[:user]),
      match:      Match::Stub.new(@channels[:match]),
      tournament: Tournament::Stub.new(@channels[:tournament]),
      auth:       Auth::Stub.new(@channels[:auth])
    }
  rescue GRPC::BadStatus => e
    raise ServerException::ServiceUnavailable.new("Failed to connect to gRPC services: #{e.message}")
  end
end

