# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_client.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:37:07 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 19:25:59 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'yaml'
require 'singleton'
require_relative '../protos/user_api_gateway_services_pb'
require_relative '../protos/match_api_gateway_services_pb'
require_relative '../protos/tournament_api_gateway_services_pb'

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
    }
    
    @stubs = {
      user:       UserAPIGateway::Stub.new(@channels[:user]),
      match:      MatchAPIGateway::Stub.new(@channels[:match]),
      tournament: TournamentAPIGateway::Stub.new(@channels[:tournament]),
    }
end

