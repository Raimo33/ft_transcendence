# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    jwt_validator.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/01 19:14:39 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 18:56:09 by craimond         ###   ########.fr        #
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
    @public_key  = OpenSSL::PKey::RSA.new(File.read(@config.dig(:jwt, :public_key))) 
  end

  def decode_incoming_session_token(token)
    JWT.decode(
      token,
      @public_key,
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
      @public_key,
      false
    )
  end

  def extract_token(auth_header)
    auth_header.split(' ').last
  end

end