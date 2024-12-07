# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    register_user_handler.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:07:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class RegisterUserHandler < BaseHandler
  def call(parsed_request)
    parsed_request = env[OpenapiFirst::REQUEST]

    response = @grpc_client.register_user(
      email:        parsed_request.parsed_params['email'],
      password:     parsed_request.parsed_params['password'],
      display_name: parsed_request.parsed_params['display_name'],
      build_request_metadata(parsed_request)
    )

    body = {
      user_id:  response.id,
    }
    
    [201, {}, [JSON.generate(body)]]
  end
end