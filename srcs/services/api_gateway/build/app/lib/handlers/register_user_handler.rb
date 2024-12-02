# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    register_user_handler.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:35:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class RegisterUserHandler < BaseHandler
  def call(request, requester_user_id)
    grpc_request = User::RegisterUserRequest.new(request.params)
    metadata = build_request_metadata(request, requester_user_id)
    response = @grpc_client.stubs[:user].register_user(grpc_request, metadata)
    
    [201, {}, [JSON.generate(response)]]
  end
end