# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    JwtValidator.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/01 19:14:39 by craimond          #+#    #+#              #
#    Updated: 2024/11/12 12:27:29 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "jwt"
require "net/http"
require "json"
require "base64"
require "openssl"
require_relative "ConfigLoader"
require_relative "ConfigurableLogger"
require_relative "../proto/auth_service_pb"

class JwtValidator

  def initialize(grpc_client)
    @config = ConfigLoader.instance.config
    @logger = ConfigurableLogger.instance.logger
    @grpc_client = grpc_client
    @public_key = nil
    @last_fetched = nil
  end

  def token_valid?(token)
    decoded_token = decode_token(token)
    return false unless decoded_token

    validate_claims(decoded_token)
  end

  def token_authorized?(token, expected_auth_level)
    decoded_token = decode_token(token)
    return false unless decoded_token

    token_auth = decoded_token[0]["auth_level"]
    return token_auth >= expected_auth_level
  end 

  def get_subject(token)
    decoded_token = decode_token(token)
    return false unless decoded_token

    decoded_token[0]["sub"]
  end

  private

  def decode_token(token)
    public_key = fetch_public_key

    JWT.decode(token, public_key, true, { algorithm: @algorithm })
  rescue StandardError => e
    @logger.error("Failed to decode token: #{e}")
    nil
  end

  def fetch_public_key
    return @public_key if @public_key && (Time.now - @last_fetched < @config[:jwt][:key_refresh_interval])
  
    @logger.debug("Fetching JWKS from Auth service")
    response = @grpc_client.call(ApiGatewayAuthService::GetJwksRequest.new)
  
    return nil unless response&.certificate
  
    @logger.debug("Parsing public key from JWKS")
    @public_key = OpenSSL::X509::Certificate.new(Base64.decode64(response.certificate)).public_key
    @algorithm = response.algorithm
    @last_fetched = Time.now
    @public_key
  rescue StandardError => e
    raise "Failed to fetch public key: #{e}"
  end

  def validate_claims(decoded_token)
    exp = decoded_token[0]["exp"] + @config[:jwt][:clock_skew]
    iat = decoded_token[0]["iat"] - @config[:jwt][:clock_skew]
    aud = decoded_token[0]["aud"]

    return false unless exp && iat && aud
    now = Time.now.to_i
    return false unless (iat..exp).cover?(now)
    return false unless aud == @config[:jwt][:audience]

    true
  end

end
