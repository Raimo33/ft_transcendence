# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    join_tournament_handler.rb                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:06:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:35:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class JoinTournamentHandler < BaseHandler
  def call(request, requester_user_id)
    grpc_request = Tournament::JoinTournamentRequest.new(request.params)
    metadata = build_request_metadata(request, requester_user_id)
    @grpc_client.stubs[:tournament].join_tournament(grpc_request, metadata)
    
    [204, {}, []]
  end
end