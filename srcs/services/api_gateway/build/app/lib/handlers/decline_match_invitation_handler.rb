# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    decline_match_invitation_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 19:29:09 by craimond          #+#    #+#              #
#    Updated: 2024/11/24 19:29:16 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'BaseHandler'

class DeclineMatchInvitationHandler < BaseHandler
  def call(params, requesting_user_id)
    grpc_request = Match::DeclineMatchInvitationRequest.new(params)
    metadata = build_request_metadata(requesting_user_id)
    response = @grpc_client.stubs[:match].decline_match_invitation(grpc_request, metadata)
    build_response_json(response)
  end
end