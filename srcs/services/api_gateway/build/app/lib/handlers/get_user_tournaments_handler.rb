# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_user_tournaments_handler.rb                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:30:02 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetUserTournamentsHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    response = @grpc_client.get_user_tournaments(
      user_id: parsed_request.parsed_params['user_id'],
      cursor:  parsed_request.parsed_params['cursor'],
      limit:   parsed_request.parsed_params['limit'],
      metadata
    )
    
    body = {
      tournament_ids: response.ids
    }

    [200, {}, [JSON.generate(body)]]
  end

end