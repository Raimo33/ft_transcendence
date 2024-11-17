# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcClient.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/17 18:33:12 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require_relative "ConfigLoader"
require_relative "ConfigurableLogger"
require_relative "Modules/GrpcClientHandler"
require_relative "../proto/user_api_gateway_pb"
require_relative "../proto/match_api_gateway_pb"
require_relative "../proto/tournament_api_gateway_pb"

class GrpcClient
  include GrpcClientHandler

  def initialize
    @logger.info("Initializing grpc client")
    
    @config   = ConfigLoader.instance.config
    @logger   = ConfigurableLogger.instance.logger
    @channels = {}
    @stubs    = {}

    channel_options = {
      "grpc.compression_algorithm" => "gzip"
    }

    @channels = {
      user:        create_channel(@config[:addresses][:user],       :this_channel_is_insecure, channel_options),
      match:       create_channel(@config[:addresses][:match],      :this_channel_is_insecure, channel_options),
      tournament:  create_channel(@config[:addresses][:tournament], :this_channel_is_insecure, channel_options),
      auth:        create_channel(@config[:addresses][:auth],       :this_channel_is_insecure, channel_options)
    }

    @stubs = {
      :user        => User::Stub.new(@channels[:user]),
      :match       => Match::Stub.new(@channels[:match]),
      :tournament  => Tournament::Stub.new(@channels[:tournament]),
      :auth        => Auth::Stub.new(@channels[:auth])
    }
  rescue StandardError => e
    raise "Failed to initialize grpc client: #{e}"
  ensure
    close
  end

  def close
    @logger.info("Closing gRPC client connections")
    @channels.each_value(&:close)
  end

  def register_user(email:, password:, display_name:, avatar:)
    handle_grpc_call(__method__) do

      grpc_request = User::RegisterUserRequest.new(
        email:        email,
        password:     password,
        display_name: display_name,
        avatar:       avatar
      )

      @stubs[:user].register_user(grpc_request)
    end
  end

  def get_user_profile(requester_user_id:, user_id:)
    handle_grpc_call(__method__) do

      grpc_request = User::GetUserProfileRequest.new(
        requester_user_id: requester_user_id,
        user_id:           user_id
      )

      @stubs[:user].get_user_profile(grpc_request)
    end
  end

  #TODO add more methods (from mapper)

  private

  def create_channel(addr, credentials)
    @logger.debug("Creating channel to #{addr}")
    GRPC::Core::Channel.new(addr, nil, credentials)
  rescue StandardError => e
    raise "Failed to create channel to #{addr}: #{e}"
  end

end
