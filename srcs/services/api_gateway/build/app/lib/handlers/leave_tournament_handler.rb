# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    leave_tournament_handler.rb                        :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:07:07 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:35:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class LeaveTournamentHandler < BaseHandler
  def call(request, requester_user_id)
    grpc_request = Tournament::LeaveTournamentRequest.new(request.params)
    metadata = build_request_metadata(request, requester_user_id)
    @grpc_client.stubs[:tournament].leave_tournament(grpc_request, metadata)
    
    [204, {}, []]
  end
end