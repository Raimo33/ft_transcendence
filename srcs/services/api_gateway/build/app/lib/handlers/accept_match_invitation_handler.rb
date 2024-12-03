# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    accept_match_invitation_handler.rb                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 19:27:51 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 18:18:44 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class AcceptMatchInvitationHandler < BaseHandler
  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]

    @grpc_client.accept_match_invitation(
      match_id: parsed_request.parsed_params['match_id']
      build_request_metadata(env)
    )
    
    [204, {}, []]
  end
end