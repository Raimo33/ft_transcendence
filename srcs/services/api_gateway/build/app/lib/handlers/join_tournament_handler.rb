# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    join_tournament_handler.rb                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:06:44 by craimond          #+#    #+#              #
#    Updated: 2024/11/24 20:06:50 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class JoinTournamentHandler < BaseHandler
  def call(params, requesting_user_id)
    grpc_request = Tournament::JoinTournamentRequest.new(params)
    metadata = build_request_metadata(requesting_user_id)
    response = @grpc_client.stubs[:tournament].join_tournament(grpc_request, metadata)
    build_response_json(response)
  end
end