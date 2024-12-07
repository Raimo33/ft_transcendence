# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    submit_tfa_code_handler.rb                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 16:43:49 by craimond         ###   ########.fr        #
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

    body = {
      session_token: response.session_token
    }

    [200, {}, [JSON.generate(body)]]
  end
end