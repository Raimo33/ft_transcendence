# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_middleware.rb                                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:14:03 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 12:25:18 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'jwt'
require_relative '../../shared/exceptions'
require_relative '../../modules/auth'

class AuthMiddleware

  def initialize(app)
    @app = app
    @auth = Auth.instance
  end

  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]
    raise InternalServerError.new('Request not found') unless parsed_request

    operation = parsed_request.operation
    required_auth_level = operation['x-auth-level']
    return @app.call(env) if required_auth_level&.zero?

    auth_header = parsed_request.headers['Authorization']
    raise Unauthorized.new('Authorization header not found') unless auth_header

    token = extract_token(auth_header)
    payload = @auth.validate_jwt(token)
    raise Forbidden.new('Wrong permissions') unless payload['auth_level'] >= required_auth_level

    @app.call(env)
  end

  def extract_token(auth_header)
    auth_header.split(' ').last
  end

end