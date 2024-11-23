# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ping_handler.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 16:01:13 by craimond          #+#    #+#              #
#    Updated: 2024/11/23 16:13:17 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class PingHandler < BaseHandler
  def call(params)
    json_response({ message: 'pong' })
  rescue GRPC::NotFound
    json_response({ error: 'User not found' }, status: 404)
  end
end