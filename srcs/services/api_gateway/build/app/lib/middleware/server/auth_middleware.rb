# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_middleware.rb                                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:14:03 by craimond          #+#    #+#              #
#    Updated: 2024/12/27 18:34:08 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'jwt'
require_relative '../../request_context'
require_relative '../../grpc_client'

class AuthMiddleware

  def initialize(app)
    @app = app
    @grpc_client  = GrpcClient.instance
  end

  def call(env)
    openapi_parsed_request = env[OpenapiFirst::REQUEST]
    raise GRPC::Internal.new('Request not found') unless openapi_request

    operation = openapi_request.operation
    required_auth_level = operation['x-auth-level']
    return @app.call(env) if required_auth_level&.zero?

    auth_header = openapi_request.headers['Authorization']
    raise GRPC::Unauthenticated.new('Authorization header not found') unless auth_header

    token = extract_token(auth_header)
    @grpc_client.validate_session_token(token)
    payload = JWT.decode(token, nil, false).first
    raise GRPC::Unauthenticated.new('Wrong permissions') unless payload['auth_level'] >= required_auth_level

    @app.call(env)
  end

  def extract_token(auth_header)
    auth_header.split(' ').last
  end

end