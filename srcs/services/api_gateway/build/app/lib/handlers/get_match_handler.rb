# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_match_handler.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 19:14:05 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 18:19:59 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetMatchHandler < BaseHandler
  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]
    response = @grpc_client.get_match(
      match_id: request.params['match_id'],
      build_request_metadata(env)
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