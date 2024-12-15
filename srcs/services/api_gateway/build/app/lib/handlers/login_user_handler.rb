# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    login_user_handler.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:30:20 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class LoginUserHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    response = @grpc_client.login_user(
      email: parsed_request.parsed_params['email'],
      password: parsed_request.parsed_params['password'],
      metadata
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