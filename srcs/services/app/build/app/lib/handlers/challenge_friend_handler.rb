# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    challenge_friend_handler.rb                        :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/15 20:20:31 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:28:01 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class ChallengeFriendHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    response = @grpc_client.challenge_friend(
      friend_id:  parsed_request.parsed_params['friend_id'],
      metadata:   metadata
    )

    [201, {}, []]
  end

end