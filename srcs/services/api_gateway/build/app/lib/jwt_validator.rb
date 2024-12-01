# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    jwt_validator.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/01 19:14:39 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 19:03:41 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'jwt'
require 'singleton'
require_relative 'ConfigHandler'
require_relative 'GrpcClient'

class JwtValidator
  include Singleton

  def initialize
    @grpc_client = GrpcClient.instance
    @config      = ConfigHandler.instance.config

    @public_keys = {
      "session_token" => OpenSSL::PKey::RSA.new(@config.dig(:jwt, :public_keys, :session_token))
      "refresh_token" => OpenSSL::PKey::RSA.new(@config.dig(:jwt, :public_keys, :refresh_token))
    }
    
  end

  def extract_token(auth_header)
    auth_header.to_s.split(' ').last
  end

  def validate_token(token, required_auth_level)
    decoded_token = decode_token(token)
    return nil unless decoded_token
  
    claims = decoded_token[0]

    user_id     = claims["sub"]
    auth_level  = claims["auth_level"].to_i
    
    return nil unless auth_level >= required_auth_level
  
    user_id
  end

  private

  def decode_incoming_session_token(token)
    JWT.decode(
      token,
      @public_keys["session_token"]
      true,
      {
       algorithm: 'RS256',
       verify_iat: true,
       verify_exp: true,
       verify_iss: true,
       iss: 'AuthService',
       leeway: @config.dig(:jwt, :leeway) || 0,
       required_claims: ['sub', 'iss', 'exp', 'jti', 'auth_level']
      }
    )
  end

  def decode_outgoing_refresh_token(token)
    JWT.decode(
      token,
      @public_keys["refresh_token"]
      false
    )
  end

end