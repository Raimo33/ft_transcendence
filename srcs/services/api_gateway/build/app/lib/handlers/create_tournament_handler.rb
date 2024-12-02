# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    create_tournament_handler.rb                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:03:14 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:35:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class CreateTournamentHandler < BaseHandler
  def call(request, requester_user_id)
    grpc_request = Tournament::CreateTournamentRequest.new(request.params)
    metadata = build_request_metadata(request, requester_user_id)
    response = @grpc_client.stubs[:tournament].create_tournament(grpc_request, metadata)
    
    [201, {}, [JSON.generate(response)]]
  end
end