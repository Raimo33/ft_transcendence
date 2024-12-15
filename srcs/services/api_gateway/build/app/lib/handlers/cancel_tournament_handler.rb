# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    cancel_tournament_handler.rb                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:05:48 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:27:57 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class CancelTournamentHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    @grpc_client.cancel_tournament(
      tournament_id: parsed_request.parsed_params[:tournament_id]
      metadata
    )
    
    [204, {}, []]
  end
  
end