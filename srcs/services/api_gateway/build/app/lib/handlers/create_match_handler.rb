# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    create_match_handler.rb                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 18:38:31 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:07:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class CreateMatchHandler < BaseHandler
  def call(parsed_request)
    parsed_request = env[OpenapiFirst::REQUEST]

    response = @grpc_client.create_match(
      opponent_id: parsed_request.parsed_params[:opponent_id]
      build_request_metadata(parsed_request)
    )
    
    body = {
      match_id: response.id,
    }

    [201, {}, [JSON.generate(body)]]
  end
end