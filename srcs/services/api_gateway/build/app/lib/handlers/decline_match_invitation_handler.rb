# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    decline_match_invitation_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 19:29:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:35:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'BaseHandler'

class DeclineMatchInvitationHandler < BaseHandler
  def call(request, requester_user_id)
    grpc_request = Match::DeclineMatchInvitationRequest.new(request.params)
    metadata = build_request_metadata(request, requester_user_id)
    @grpc_client.stubs[:match].decline_match_invitation(grpc_request, metadata)
    
    [204, {}, []]
  end
end