# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_match_handler.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 19:14:05 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:07:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetMatchHandler < BaseHandler
  def call(parsed_request)
    parsed_request = env[OpenapiFirst::REQUEST]
    response = @grpc_client.get_match(
      match_id: request.params['match_id'],
      build_request_metadata(parsed_request)
    )
    
    body = {
      match: {
        id:             response.id,
        creator_id:     response.creator_id,
        player_ids:     response.player_ids,
        status:         response.status,
        started_at:     response.started_at,
        finished_at:    response.finished_at
      }
    }

    [200, {}, [JSON.generate(body)]]
  end
end