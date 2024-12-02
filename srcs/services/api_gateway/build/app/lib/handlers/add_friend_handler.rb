# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    add_friend_handler.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 18:34:30 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:35:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class AddFriendHandler < BaseHandler
  def call(request, requester_user_id)
    grpc_request = User::AddFriendRequest.new(request.params)
    metadata = build_request_metadata(request, requester_user_id)
    @grpc_client.stubs[:user].add_friend(grpc_request, metadata)
    
    [204, {}, []]
  end
end