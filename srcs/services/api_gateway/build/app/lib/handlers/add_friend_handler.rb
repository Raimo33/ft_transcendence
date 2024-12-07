# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    add_friend_handler.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 18:34:30 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:07:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class AddFriendHandler < BaseHandler
  def call(parsed_request)
    parsed_request = env[OpenapiFirst::REQUEST]

    @grpc_client.add_friend(
      friend_id: parsed_request.parsed_params[:friend_id]
      build_request_metadata(parsed_request)
    )
    
    [204, {}, []]
  end
end