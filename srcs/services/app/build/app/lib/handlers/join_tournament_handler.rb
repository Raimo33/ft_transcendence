# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    join_tournament_handler.rb                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:06:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:30:05 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class JoinTournamentHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    @grpc_client.join_tournament(
      tournament_id: parsed_request.parsed_params['tournament_id'],
      metadata
    )
    
    [204, {}, []]
  end
  
end