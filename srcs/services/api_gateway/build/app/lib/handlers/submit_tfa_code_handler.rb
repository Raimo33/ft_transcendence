# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    submit_tfa_code_handler.rb                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:07:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class SubmitTFACodeHandler < BaseHandler
  def call(parsed_request)
    parsed_request = env[OpenapiFirst::REQUEST]

    response = @grpc_client.submit_tfa_code(
      code: parsed_request.parsed_params[:code],
      build_request_metadata(parsed_request)
    )

    body = {
      session_token: response.session_token
    }

    [200, {}, [JSON.generate(body)]]
  end
end