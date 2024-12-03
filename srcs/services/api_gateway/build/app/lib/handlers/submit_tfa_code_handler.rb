# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    submit_tfa_code_handler.rb                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 18:23:12 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class SubmitTFACodeHandler < BaseHandler
  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]

    response = @grpc_client.submit_tfa_code(
      code: parsed_request.parsed_params[:code],
      build_request_metadata(env)
    )
    
    headers = {
      'Set-Cookie' => build_refresh_token_cookie_header(response.refresh_token),
    }

    body = {
      session_token: response.session_token
    }

    [200, headers, [JSON.generate(body)]]
  end
end