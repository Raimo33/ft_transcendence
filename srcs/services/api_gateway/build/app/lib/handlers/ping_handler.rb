# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ping_handler.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 16:01:13 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:24:17 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class PingHandler < BaseHandler

  def call(parsed_request)
    [ 200, { 'Content-Type' => 'text/plain' }, ['pong...FUMASTERS!'] ]
  end
  
end