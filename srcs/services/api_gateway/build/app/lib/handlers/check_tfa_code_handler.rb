# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    check_tfa_code_handler.rb                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/11/28 14:52:00 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class SubmitTFACodeHandler < BaseHandler
  def call(params, requesting_user_id)
    grpc_request = User::SubmitTFACodeRequest.new(params)
    metadata = build_request_metadata(requesting_user_id)
    response = @grpc_client.stubs[:user].check_tfa_code(grpc_request, metadata)
    build_response_json(response)
  end
end