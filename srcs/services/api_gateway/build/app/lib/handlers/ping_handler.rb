# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ping_handler.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 16:01:13 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 17:56:35 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class PingHandler < BaseHandler
  def call(env)
    [ 200, { 'Content-Type' => 'text/plain' }, ['pong...FUMASTERS!'] ]
  end
end