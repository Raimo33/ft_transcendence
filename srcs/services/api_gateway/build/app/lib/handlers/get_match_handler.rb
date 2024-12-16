# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_match_handler.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 19:14:05 by craimond          #+#    #+#              #
#    Updated: 2024/12/16 18:32:45 by craimond         ###   ########.fr        #
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
        finished_at:    response.finished_at.seconds
      }
    }

    [200, {}, [JSON.generate(body)]]
  end
  
end