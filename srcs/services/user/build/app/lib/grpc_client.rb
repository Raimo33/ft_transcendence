# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_client.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/12/17 17:55:13 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'singleton'
require_relative 'ConfigHandler'
require_relative '../protos/auth_user_services_pb'
require_relative '../protos/notification_user_services_pb'
require_relative 'interceptors/metadata_interceptor'
require_relative 'interceptors/logger_interceptor'

class GrpcClient
  include Singleton
  
  def initialize
    @config = ConfigHandler.instance.config

    @connection_options = {
      "grpc.compression_algorithm" => "gzip"
    }

    interceptors = [
      MetadataInterceptor.new,
      LoggerInterceptor.new
    ]

    @channels = {
      auth: create_channel(@config.dig(:grpc, :client, :addresses, :auth))
      notification: create_channel(@config.dig(:grpc, :client, :addresses, :notification))
    }

    @stubs = {
      auth: AuthUser::Stub.new(@channels[:auth], interceptors: interceptors)
      notification: NotificationUser::Stub.new(@channels[:notification], interceptors: interceptors)
    }
  ensure
    stop
  end

  def stop
    @channels.each_value(&:close)
  end

  def check_domain(domain:, metadata = {})
    request = AuthUser::Domain(domain: domain)
    @stubs[:auth].check_domain(request, metadata: metadata)
  end

  def hash_password(password:, metadata = {})
    request = AuthUser::Password(password: password)
    @stubs[:auth].hash_password(request, metadata: metadata)
  end

  def validate_password(password:, hashed_password:, metadata = {})
    request = AuthUser::ValidatePasswordRequest(password: password, hashed_password: hashed_password)
    @stubs[:auth].validate_password(request, metadata: metadata)
  end

  def generate_tfa_secret(user_id: nil, metadata = {})
    request = AuthUser::Identifier(user_id: user_id)
    @stubs[:auth].generate_tfa_secret(request, metadata: metadata)
  end

  def check_tfa_code(tfa_secret:, tfa_code:, metadata = {})
    request = AuthUser::CheckTFACodeRequest(tfa_secret: tfa_secret, tfa_code: tfa_code)
    @stubs[:auth].check_tfa_code(request, metadata: metadata)
  end

  def generate_jwt(identifier:, ttl:, custom_claims:, metadata = {})
    request = AuthUser::GenerateJWTRequest(
      identifier:     identifier,
      ttl:            ttl,
      custom_claims:  Google::Protobuf::Struct.from_hash(custom_claims)
    )
    @stubs[:auth].generate_jwt(request, metadata: metadata)
  end

  def validate_refresh_token(refresh_token:, metadata = {})
    request = AuthUser::JWT(jwt: jwt)
    @stubs[:auth].validate_refresh_token(request, metadata: metadata)
  end

  def extend_jwt(jwt:, ttl:, metadata = {})
    request = AuthUser::JWT(jwt: jwt)
    @stubs[:auth].extend_jwt(request, metadata: metadata)
  end

  def notify_clients(user_ids:, event:, payload:, metadata = {})
    request = NotificationUser::NotifyClientsRequest(
      user_ids: user_ids,
      event:    event,
      payload:  Google::Protobuf::Struct.from_hash(payload)
    )

    @stubs[:notification].notify_clients(request, metadata: metadata)
  end

  private

  def create_channel(addr)
    GRPC::Core::Channel.new(addr, @connection_options, credentials: :this_channel_is_insecure)
  end

end
