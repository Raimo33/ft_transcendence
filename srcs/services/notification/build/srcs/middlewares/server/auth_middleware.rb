# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_middleware.rb                                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:14:03 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 15:03:27 by craimond         ###   ########.fr        #
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
    auth_header = 
    raise Unauthorized.new("Authorization header not found") unless auth_header

    session_token = extract_session_token(auth_header)
    payload = @auth_module.validate_jwt(session_token)
    raise Forbidden.new("Wrong permissions") unless payload["auth_level"] >= 1

    RequestContext.requester_user_id = payload["sub"]

    @app.call(env)
  ensure
    RequestContext.clear
  end

  def extract_session_token(auth_header)
    auth_header.split(' ').last
  end

end