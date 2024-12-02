# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    accept_match_invitation_handler.rb                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 19:27:51 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:35:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class AcceptMatchInvitationHandler < BaseHandler
  def call(request, requester_user_id)
    grpc_request = Match::AcceptMatchInvitationRequest.new(request.params)
    metadata = build_request_metadata(request, requester_user_id)
    @grpc_client.stubs[:match].accept_match_invitation(grpc_request, metadata)
    
    [204, {}, []]
  end
end