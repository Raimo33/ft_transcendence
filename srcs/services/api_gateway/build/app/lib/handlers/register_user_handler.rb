# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    register_user_handler.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 17:47:52 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class RegisterUserHandler < BaseHandler
  def call(params, requester_user_id)
    grpc_request = User::RegisterUserRequest.new(params)
    metadata = build_request_metadata(requester_user_id)
    response = @grpc_client.stubs[:user].register_user(grpc_request, metadata)
    
    [201, {}, [response.to_json]]
  end
end