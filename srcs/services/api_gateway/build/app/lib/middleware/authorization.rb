# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    authorization.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:14:03 by craimond          #+#    #+#              #
#    Updated: 2024/11/28 04:33:53 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../jwt_validator'

class Authorization
  def initialize(app)
    @app = app
    @jwt_validator = JwtValidator.instance
  end

  def call(env)
    request = Rack::Request.new(env)
    openapi_request = env[OpenapiFirst::REQUEST]
    return unauthorized unless openapi_request

    operation = openapi_request.operation
    auth_level = operation['x-auth-level']
    return @app.call(env) unless auth_level

    auth_header = request.env['HTTP_AUTHORIZATION']
    return unauthorized unless auth_header

    user_id = @jwt_validator.validate_token(auth_header, auth_level)
    if user_id
      env['requesting_user_id'] = user_id
      @app.call(env)
    else
      unauthorized
    end
  end

  private

  def unauthorized
    [401, {'Content-Type' => 'application/json'}, [{error: 'Unauthorized'}].to_json]
  end
end
