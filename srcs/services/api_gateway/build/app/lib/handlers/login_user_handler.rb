# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    login_user_handler.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 18:22:17 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class LoginUserHandler < BaseHandler
  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]

    response = @grpc_client.login_user(
      email: parsed_request.parsed_params['email'],
      password: parsed_request.parsed_params['password'],
      build_request_metadata(env)
    )
    
    headers = {
      'Set-Cookie' => build_refresh_token_cookie_header(response.tokens.refresh_token),
    }

    body = {
      session_token: response.tokens.session_token,
      pending_tfa:   response.pending_tfa
    }

    [200, headers, [JSON.generate(body)]]
  end
end