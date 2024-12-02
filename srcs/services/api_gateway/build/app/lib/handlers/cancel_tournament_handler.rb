# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    cancel_tournament_handler.rb                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:05:48 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:35:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class CancelTournamentHandler < BaseHandler
  def call(request, requester_user_id)
    grpc_request = Tournament::CancelTournamentRequest.new(request.params)
    metadata = build_request_metadata(request, requester_user_id)
    @grpc_client.stubs[:tournament].cancel_tournament(grpc_request, metadata)
    
    [204, {}, []]
  end
end