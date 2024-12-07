# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_friends_handler.rb                             :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 18:35:36 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:07:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetFriendsHandler < BaseHandler
  def call(parsed_request)
    response = @grpc_client.get_friends(build_request_metadata(parsed_request))
    
    body = {
      friend_ids: response.ids
    }

    [200, {}, [JSON.generate(body)]]
  end
end