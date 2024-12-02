# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    submit_tfa_code_handler.rb                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:35:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class SubmitTFACodeHandler < BaseHandler
  def call(request, requester_user_id)
    grpc_request = User::SubmitTFACodeRequest.new(request.params)
    metadata = build_request_metadata(request, requester_user_id)
    response = @grpc_client.stubs[:user].check_tfa_code(grpc_request, metadata)
    
    headers = {
      'Set-Cookie' => build_refresh_token_cookie_header(response.refresh_token),
    }

    body = {
      session_token: response.session_token
    }

    [200, headers, [JSON.generate(body)]]
  end
end