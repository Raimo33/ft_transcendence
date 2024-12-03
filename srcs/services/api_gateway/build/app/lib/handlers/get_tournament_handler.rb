# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_tournament_handler.rb                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:05:08 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 18:20:12 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetTournamentHandler < BaseHandler
  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]

    response = @grpc_client.get_tournament(
      tournament_id: request.params['tournament_id']
      build_request_metadata(env)
    )

    body = {
      tournament: {
        id:             response.id,
        creator_id:     response.creator_id,
        match_ids:      response.match_ids,
        status:         response.status,
        started_at:     response.started_at,
        finished_at:    response.finished_at
      }
    }
    
    [200, {}, [JSON.generate(body)]]
  end
end