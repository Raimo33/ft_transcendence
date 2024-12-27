# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_game_state_service_handler.rb                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/27 18:24:57 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require_relative '../config_handler'
require_relative '../grpc_server'
require_relative '../jwt_validator'
require_relative '../protos/auth_game_state_services_pb'

class AuthGameStateServiceHandler < AuthGameState::Service

  def initialize
    @config = ConfigHandler.instance.config
    @jwt_validator = JwtValidator.instance
  end

  def ping(_request, _call)
    Empty.new
  end

  def validate_session_token(request, _call)
    check_required_fields(request.jwt)

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

    Empty.new
  end

  private

end