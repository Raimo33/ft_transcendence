# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    stop_matchmaking_handler.rb                        :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/15 20:19:52 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:25:53 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class StopMatchmakingHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    response = @grpc_client.stop_matchmaking(metadata)

    [204, {}, []]
  end

end