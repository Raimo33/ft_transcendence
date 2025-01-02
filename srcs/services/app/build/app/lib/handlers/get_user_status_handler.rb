# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_user_status_handler.rb                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:29:56 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetUserStatusHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    response = @grpc_client.get_user_status(
      user_id: parsed_request.parsed_params['user_id'],
      metadata
    )
    
    body = {
      status: response.status,
    }

    [200, {}, [JSON.generate(body)]]
  end
  
end