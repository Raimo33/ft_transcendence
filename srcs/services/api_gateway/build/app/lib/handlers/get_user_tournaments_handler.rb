# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_user_tournaments_handler.rb                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 18:21:05 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetUserTournamentsHandler < BaseHandler
  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]

    response = @grpc_client.get_user_tournaments(
      user_id: parsed_request.parsed_params['user_id'],
      build_request_metadata(env)
    )
    
    body = {
      tournament_ids: response.ids
    }

    [200, {}, [JSON.generate(body)]]
  end
end