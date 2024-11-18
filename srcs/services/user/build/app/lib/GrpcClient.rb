# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcClient.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/18 15:54:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require_relative "ConfigLoader"
require_relative "ConfigurableLogger"
require_relative "../proto/auth_pb"
require_relative "modules/GrpcClientErrorHandler"

class GrpcClient
  include GrpcClientErrorHandler
  
  def initialize
    @config   = ConfigLoader.config
    @logger   = ConfigurableLogger.instance.logger

    @logger.info("Initializing gRPC client")
    @channels = {}
    @stubs    = {}

    connection_options = {
      "grpc.compression_algorithm" => "gzip"
    }

    @channels = {
      auth: create_channel(@config[:addresses][:auth], :this_channel_is_insecure, connection_options)
    }

    @stubs = {
      auth: AuthUserService::Stub.new(@channels[:auth])
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

  def generate_2fa_secret(:user_id)
    handle_grpc_call(__method__) do
      grpc_request   = AuthUserService::Generate2faSecretRequest.new(user_id: user_id)
      @stubs["auth"].generate_2fa_secret(grpc_request)
    end
  end

  def check_2fa_code(:totp_secret, :totp_code)
    handle_grpc_call(__method__) do
      grpc_request   = AuthUserService::Check2faCodeRequest.new(totp_secret: totp_secret, totp_code: totp_code)
      @stubs["auth"].check_2fa_code(grpc_request)
    end
  end

  def generate_jwt(:user_id, :auth_level, :pending_2fa)
    handle_grpc_call(__method__) do
      grpc_request   = AuthUserService::GenerateJwtRequest.new(user_id: user_id, auth_level: auth_level, pending_2fa: pending_2fa)
      @stubs["auth"].generate_jwt(grpc_request)
    end
  end

  def check_domain(:domain)
    handle_grpc_call(__method__) do
      grpc_request   = AuthUserService::CheckDomainRequest.new(domain: domain)
      @stubs["auth"].check_domain(grpc_request)
    end
  end

  def hash_password(:password)
    handle_grpc_call(__method__) do
      grpc_request   = AuthUserService::HashPasswordRequest.new(password: password)
      @stubs["auth"].hash_password(grpc_request)
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
