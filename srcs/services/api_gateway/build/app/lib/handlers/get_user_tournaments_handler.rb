# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_user_tournaments_handler.rb                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:35:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetUserTournamentsHandler < BaseHandler
  def call(request, requester_user_id)
    grpc_request = User::GetUserTournamentsRequest.new(request.params)
    metadata = build_request_metadata(request, requester_user_id)
    response = @grpc_client.stubs[:tournament].get_user_tournaments(grpc_request, metadata)
    
    [200, {}, [JSON.generate(response)]]
  end
end