# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_user_status_handler.rb                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:07:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetUserStatusHandler < BaseHandler
  def call(parsed_request)
    parsed_request = env[OpenapiFirst::REQUEST]

    response = @grpc_client.get_user_status(
      user_id: parsed_request.parsed_params['user_id'],
      build_request_metadata(parsed_request)
    )
    
    body = {
      status: response.status,
    }

    [200, {}, [JSON.generate(body)]]
  end
end