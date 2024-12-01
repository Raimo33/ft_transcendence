# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    accept_match_invitation_handler.rb                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 19:27:51 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 14:51:31 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class AcceptMatchInvitationHandler < BaseHandler
  def call(params, requester_user_id)
    grpc_request = Match::AcceptMatchInvitationRequest.new(params)
    metadata = build_request_metadata(requester_user_id)
    response = @grpc_client.stubs[:match].accept_match_invitation(grpc_request, metadata)
    build_response_json(response)
  end
end