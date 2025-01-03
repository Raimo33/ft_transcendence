# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_match_handler.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 19:14:05 by craimond          #+#    #+#              #
#    Updated: 2024/12/17 19:05:32 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetMatchHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    response = @grpc_client.get_match(
      match_id: request.params['match_id'],
      metadata
    )
    
    body = {
      match: {
        id:             response.id,
        player_ids:     response.player_ids,
        status:         response.status,
        started_at:     response.started_at.seconds,
        ended_at:    response.ended_at.seconds
        tournament_id:  response.tournament_id
      }
    }

    [200, {}, [JSON.generate(body)]]
  end
  
end