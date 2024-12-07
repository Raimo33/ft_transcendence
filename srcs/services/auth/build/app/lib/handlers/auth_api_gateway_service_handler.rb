# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_api_gateway_service_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 18:50:31 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require 'bcrypt'
require 'rotp'
require 'resolv'
require_relative '../config_handler'
require_relative '../grpc_server'
require_relative '../protos/auth_api_gateway_pb'

class AuthApiGatewayServiceHandler < AuthApiGateway::Service

  def initialize
    @config = ConfigHandler.instance.config
    @private_key = OpenSSL::PKey::RSA.new(@config[:jwt][:private_key])
  end

  def ping(_request, _call)
    Empty.new
  end

  def decode_jwt(request, call)
    check_required_fields(request.jwt)

    settings = @config[:jwt]
    payload, headers = JWT.decode(
      request.jwt,
      @private_key.public_key,
      true,
      {
        algorithm: settings.fetch(:algorithm, 'RS256'),
        verify_iss: true,
        verify_aud: true,
        iss:        settings.fetch(:issuer, 'AuthService'),
        aud:        settings.fetch(:audience, nil)
      }
    ).first

    AuthUser::DecodedJWT.new(
      payload: Google::Protobuf::Struct.from_hash(payload),
      headers: Google::Protobuf::Struct.from_hash(headers)
    )
  end

  private

end