# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_tournament_handler.rb                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:05:08 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:35:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetTournamentHandler < BaseHandler
  def call(request, requester_user_id)
    grpc_request = Tournament::GetTournamentRequest.new(request.params)
    metadata = build_request_metadata(request, requester_user_id)
    response = @grpc_client.stubs[:tournament].get_tournament(grpc_request, metadata)
    
    [200, {}, [JSON.generate(response)]]
  end
end