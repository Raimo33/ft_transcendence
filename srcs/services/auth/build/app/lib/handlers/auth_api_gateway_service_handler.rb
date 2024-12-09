# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_api_gateway_service_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/09 19:06:33 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require 'bcrypt'
require 'rotp'
require 'resolv'
require_relative '../config_handler'
require_relative '../grpc_server'
require_relative '../jwt_validator'
require_relative '../protos/auth_api_gateway_pb'

class AuthApiGatewayServiceHandler < AuthApiGateway::Service

  def initialize
    @config = ConfigHandler.instance.config
    @jwt_validator = JwtValidator.instance
  end

  def ping(_request, _call)
    Empty.new
  end

  def validate_session_token(request, _call)
    check_required_fields(request.jwt, request.required_auth_level)

    settings = @config[:jwt]
    payload, headers = JWT.decode(
      request.jwt,
      @private_key.public_key,
      true,
      {
        algorithm: settings.fetch(:algorithm, 'RS256'),
        required_claims: %w[sub iat exp iss aud jti auth_level],
        verify_exp: true,
        verify_iat: true,
        verify_iss: true,
        verify_aud: true,
        iss: settings.fetch(:issuer, 'AuthService'),
        aud: settings.fetch(:audience, nil)
        iat: Time.now.to_i,
        leeway: settings.fetch(:leeway, 0)
      }
    )

    raise GRPC::Unauthenticated.new('Revoked token') if @jwt_validator.token_revoked?(payload['sub'], payload['iat'])
    raise GRPC::Unauthenticated.new('Wrong permissions') unless payload['auth_level'] >= request.required_auth_level

    Empty.new
  end

  private

  def token_revoked?(user_id, iat)
    token_invalid_before = @redis_client.get("user:#{user_id}:token_invalid_before")
    return true if token_invalid_before.nil?

    iat < token_invalid_before.to_i
  end

end