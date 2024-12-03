# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    remove_friend_handler.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 18:36:26 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 18:23:02 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class RemoveFriendHandler < BaseHandler
  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]

    @grpc_client.remove_friend(
      friend_id: parsed_request.parsed_params[:friend_id],
      build_request_metadata(env)
    )
    
    [204, {}, []]
  end
end