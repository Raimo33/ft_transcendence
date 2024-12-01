# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logout_user_handler.rb                             :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/01 14:46:51 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 14:53:43 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class LogoutUserHandler < BaseHandler
  def call(params, requester_user_id)
    metadata = build_request_metadata(requester_user_id)
    response = @grpc_client.stubs[:user].logout_user(metadata)
    build_response_json(response)
  end
end