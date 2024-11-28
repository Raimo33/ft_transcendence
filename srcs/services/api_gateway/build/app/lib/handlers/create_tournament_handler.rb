# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    create_tournament_handler.rb                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:03:14 by craimond          #+#    #+#              #
#    Updated: 2024/11/24 20:06:19 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class CreateTournamentHandler < BaseHandler
  def call(params, requesting_user_id)
    grpc_request = Tournament::CreateTournamentRequest.new(params)
    metadata = build_request_metadata(requesting_user_id)
    response = @grpc_client.stubs[:tournament].create_tournament(grpc_request, metadata)
    build_response_json(response, 201)
  end
end