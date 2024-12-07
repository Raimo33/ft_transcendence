# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    join_tournament_handler.rb                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:06:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:07:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class JoinTournamentHandler < BaseHandler
  def call(parsed_request)
    parsed_request = env[OpenapiFirst::REQUEST]

    @grpc_client.join_tournament(
      tournament_id: parsed_request.parsed_params['tournament_id'],
      build_request_metadata(parsed_request)
    )
    
    [204, {}, []]
  end
end