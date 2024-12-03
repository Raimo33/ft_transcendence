# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    cancel_tournament_handler.rb                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:05:48 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 18:18:56 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class CancelTournamentHandler < BaseHandler
  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]

    @grpc_client.cancel_tournament(
      tournament_id: parsed_request.parsed_params[:tournament_id]
      build_request_metadata(env)
    )
    
    [204, {}, []]
  end
end