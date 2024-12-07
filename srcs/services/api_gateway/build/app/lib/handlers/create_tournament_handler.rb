# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    create_tournament_handler.rb                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:03:14 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:07:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class CreateTournamentHandler < BaseHandler
  def call(parsed_request)
    response = @grpc_client.create_tournament(build_request_metadata(parsed_request))
    
    body = {
      tournament_id: response.id,
    }

    [201, {}, [JSON.generate(body)]]
  end
end