# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    add_friend_handler.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 18:34:30 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:27:47 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class AddFriendHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    @grpc_client.add_friend(
      friend_id: parsed_request.parsed_params[:friend_id]
      metadata
    )
    
    [204, {}, []]
  end
  
end