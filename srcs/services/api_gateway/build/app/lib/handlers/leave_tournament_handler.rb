# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    leave_tournament_handler.rb                        :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:07:07 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 17:04:13 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class LeaveTournamentHandler < BaseHandler
  def call(params, requester_user_id)
    grpc_request = Tournament::LeaveTournamentRequest.new(params)
    metadata = build_request_metadata(requester_user_id)
    @grpc_client.stubs[:tournament].leave_tournament(grpc_request, metadata)
    
    [204, {}, []]
  end
end