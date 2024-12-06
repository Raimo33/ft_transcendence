# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_client.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/12/06 19:55:44 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'singleton'
require_relative 'ConfigHandler'
require_relative '../protos/auth_user_services_pb'

class GrpcClient
  include Singleton
  
  #TODO il metadata in uscita deve mantenere il request-id di quello in ingresso (per fare il propagate del request-id originale dell'utente)

  def initialize
    @config = ConfigHandler.instance.config

    @connection_options = {
      "grpc.compression_algorithm" => "gzip"
    }

    interceptors = [MetadataInterceptor.new]

    @channels = {
      auth: create_channel(@config.dig(:grpc, :addresses, :auth))
    }

    @stubs = {
      auth: AuthUser::Stub.new(@channels[:auth], interceptors: interceptors)
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

  def decode_jwt(jwt:, metadata = {})
    request = AuthUser::JWT(jwt: jwt)
    @stubs[:auth].decode_jwt(request, metadata: metadata)
  end

  def rotate_jwt(jwt:, metadata = {})
    request = AuthUser::JWT(jwt: jwt)
    @stubs[:auth].rotate_jwt(request, metadata: metadata)
  end

  def revoke_jwt(jwt:, metadata = {})
    request = AuthUser::JWT(jwt: jwt)
    @stubs[:auth].revoke_jwt(request, metadata: metadata)
  end

  private

  def create_channel(addr)
    GRPC::Core::Channel.new(addr, @connection_options)
  end

end
