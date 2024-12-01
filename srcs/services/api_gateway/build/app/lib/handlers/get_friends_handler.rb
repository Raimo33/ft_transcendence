# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_friends_handler.rb                             :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 18:35:36 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 16:56:18 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetFriendsHandler < BaseHandler
  def call(params, requester_user_id)
    grpc_request = Google::Protobuf::Empty.new
    metadata = build_request_metadata(requester_user_id)
    response = @grpc_client.stubs[:user].get_friends(grpc_request, metadata)
    
    [200, {}, [response.to_json]]
  end
end