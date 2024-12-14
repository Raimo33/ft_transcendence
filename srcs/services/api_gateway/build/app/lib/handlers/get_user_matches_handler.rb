# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_user_matches_handler.rb                        :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/14 13:58:51 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetUserMatchesHandler < BaseHandler
  def call(parsed_request)
    parsed_request = env[OpenapiFirst::REQUEST]

    response = @grpc_client.get_user_matches(
      user_id:  parsed_request.parsed_params['user_id'],
      cursor:   parsed_request.parsed_params['cursor'],
      limit:    parsed_request.parsed_params['limit'],
      build_request_metadata(parsed_request)
    )
    
    body = {
      match_ids: response.ids
    }

    [200, {}, [JSON.generate(body)]]
  end
end