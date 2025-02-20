# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_middleware.rb                                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:14:03 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 15:01:57 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'jwt'
require_relative '../../shared/exceptions'
require_relative '../../modules/auth_module'

class AuthMiddleware

  def initialize(app)
    @app = app
    @auth_module = AuthModule.instance
  end

  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]
    raise InternalServerError.new("Request not found") unless parsed_request

    operation = parsed_request.operation
    required_auth_level = operation["x-auth-level"]
    return @app.call(env) if required_auth_level&.zero?

    auth_header = parsed_request.parsed_headers["Authorization"]
    raise Unauthorized.new("Authorization header not found") unless auth_header

    session_token = extract_session_token(auth_header)
    payload = @auth_module.validate_jwt(session_token)
    raise Forbidden.new("Wrong permissions") unless payload["auth_level"] >= required_auth_level

    RequestContext.requester_user_id = payload["sub"]
    RequestContext.session_token = session_token

    refresh_token_cookie = parsed_request.parsed_cookies["refresh_token"]
    return @app.call(env) unless refresh_token_cookie

    refresh_token = extract_refresh_token(refresh_token_cookie)
    RequestContext.refresh_token = refresh_token

    @app.call(env)
  ensure
    RequestContext.clear
  end

  def extract_session_token(auth_header)
    auth_header.split(' ').last
  end

  def extract_refresh_token(refresh_token_cookie)
    refresh_token_cookie.split('=').last
  end

end