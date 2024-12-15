# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    start_matchmaking_handler.rb                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 18:38:31 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:25:55 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class StartMatchmakingHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    response = @grpc_client.start_matchmaking(metadata)

    [204, {}, []]
  end

end