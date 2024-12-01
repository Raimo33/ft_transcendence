# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_user_matches_handler.rb                        :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 14:51:34 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetUserMatchesHandler < BaseHandler
  def call(params, requester_user_id)
    grpc_request = User::GetUserMatchesRequest.new(params)
    metadata = build_request_metadata(requester_user_id)
    response = @grpc_client.stubs[:match].get_user_matches(grpc_request, metadata)
    build_response_json(response)
  end
end