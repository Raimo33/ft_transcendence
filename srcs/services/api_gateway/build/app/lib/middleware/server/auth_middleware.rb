# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_middleware.rb                                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:14:03 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:08:13 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../../request_context'
require_relative '../../grpc_client'

class AuthMiddleware

  def initialize(app)
    @app = app
    @grpc_client = GrpcClient.instance
  end

  def call(env)
    openapi_parsed_request = env[OpenapiFirst::REQUEST]
    raise GRPC::Internal.new('Request not found') unless openapi_request

    operation = openapi_request.operation
    auth_level = operation['x-auth-level']
    return @app.call(env) if auth_level&.zero?

    auth_header = openapi_request.headers['Authorization']
    raise GRPC::Unauthenticated.new('Authorization header not found') unless auth_header

    token = extract_token(auth_header)
    decoded_jwt = @grpc_client.decode_jwt(token)
    token_auth_level = decoded_jwt.payload['auth_level']&.number_value || 0
    raise GRPC::Unauthenticated.new('Wrong permissions') unless token_auth_level >= auth_level

    RequestContext.requester_user_id = decoded_jwt.payload['user_id']&.number_value
    @app.call(env)
  end

  def extract_token(auth_header)
    auth_header.split(' ').last
  end

end