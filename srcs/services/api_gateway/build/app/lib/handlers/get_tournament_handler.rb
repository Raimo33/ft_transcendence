# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_tournament_handler.rb                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:05:08 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 16:56:29 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetTournamentHandler < BaseHandler
  def call(params, requester_user_id)
    grpc_request = Tournament::GetTournamentRequest.new(params)
    metadata = build_request_metadata(requester_user_id)
    response = @grpc_client.stubs[:tournament].get_tournament(grpc_request, metadata)
    
    [200, {}, [response.to_json]]
  end
end