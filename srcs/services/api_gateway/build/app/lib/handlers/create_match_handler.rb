# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    create_match_handler.rb                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 18:38:31 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 14:51:32 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class CreateMatchHandler < BaseHandler
  def call(params, requester_user_id)
    grpc_request = Match::CreateMatchRequest.new(params)
    metadata = build_request_metadata(requester_user_id)
    response = @grpc_client.stubs[:match].create_match(grpc_request, metadata)
    build_response_json(response, 201)
  end
end