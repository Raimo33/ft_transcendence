# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    leave_match_handler.rb                             :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 19:17:33 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:35:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class LeaveMatchHandler < BaseHandler
  def call(request, requester_user_id)
    grpc_request = Match::LeaveMatchRequest.new(request.params)
    metadata = build_request_metadata(request, requester_user_id)
    response = @grpc_client.stubs[:match].leave_match(grpc_request, metadata)
    
    [204, {}, []]
  end
end