# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    authorization.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:14:03 by craimond          #+#    #+#              #
#    Updated: 2024/11/28 15:27:57 by craimond         ###   ########.fr        #
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

    jwt = @jwt_validator.extract_token(auth_header)
    if user_id = @jwt_validator.validate_token(jwt, operation['operationId'], auth_level)
      env['x-requester-user-id'] = user_id
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
