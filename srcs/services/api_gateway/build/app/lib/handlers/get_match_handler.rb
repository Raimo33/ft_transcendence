# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_match_handler.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 19:14:05 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 16:56:21 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetMatchHandler < BaseHandler
  def call(params, requester_user_id)
    grpc_request = Match::GetMatchRequest.new(params)
    metadata = build_request_metadata(requester_user_id)
    response = @grpc_client.stubs[:match].get_match(grpc_request, metadata)
    
    [200, {}, [response.to_json]]
  end
end