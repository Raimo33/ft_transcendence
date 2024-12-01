# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    accept_match_invitation_handler.rb                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 19:27:51 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 16:59:59 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class AcceptMatchInvitationHandler < BaseHandler
  def call(params, requester_user_id)
    grpc_request = Match::AcceptMatchInvitationRequest.new(params)
    metadata = build_request_metadata(requester_user_id)
    @grpc_client.stubs[:match].accept_match_invitation(grpc_request, metadata)
    
    [204, {}, []]
  end
end