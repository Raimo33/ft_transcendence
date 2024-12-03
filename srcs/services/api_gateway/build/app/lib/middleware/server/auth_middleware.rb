# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_middleware.rb                                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:14:03 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 21:59:24 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../../jwt_validator'

class AuthMiddleware

  def initialize(app)
    @app = app
    @jwt_validator = JwtValidator.instance
  end

  def call(env)
    openapi_parsed_request = env[OpenapiFirst::REQUEST]
    raise GRPC::Internal.new('Request not found') unless openapi_request

    operation = openapi_request.operation
    auth_level = operation['x-auth-level']
    return @app.call(env) if auth_level&.zero?

    auth_header = openapi_request.headers['Authorization']
    raise GRPC::Unauthenticated.new('Authorization header not found') unless auth_header

    #TODO chiamare il metodo validate_token di AuthService
    raise GRPC::Unauthenticated.new('Wrong permissions') unless #decoded_token[0]['auth_level'] >= auth_level

    env['REQUESTER_USER_ID'] = decoded_token[0]['sub']
    @app.call(env)
  end

end