# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_middleware.rb                                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:14:03 by craimond          #+#    #+#              #
#    Updated: 2024/12/08 14:42:23 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../../request_context'
require_relative '../../grpc_client'

class AuthMiddleware

  def initialize(app)
    @app = app
    @grpc_client  = GrpcClient.instance
    @redis_client = RedisClient.instance
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
    payload = @grpc_client.decode_jwt(token)&.payload

    sub = payload['sub']&.number_value
    iat = payload['iat']&.number_value
    raise GRPC::Unauthenticated.new('Revoked token') if token_revoked?(sub, iat)

    token_auth_level = payload['auth_level']&.number_value || 0
    raise GRPC::Unauthenticated.new('Wrong permissions') unless token_auth_level >= auth_level

    @app.call(env)
  end

  def extract_token(auth_header)
    auth_header.split(' ').last
  end

  def token_revoked?(user_id, iat)
    token_invalid_before = @redis_client.get("user:#{user_id}:token_invalid_before")
    return true if token_invalid_before.nil?

    iat < token_invalid_before.to_i
  end

end