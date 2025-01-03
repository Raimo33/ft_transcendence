# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_context.rb                                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/06 20:25:23 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:09:06 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class RequestContext

  def self.request_id
    Thread.current[:request_id]
  end

  def self.request_id=(value)
    Thread.current[:request_id] = value
  end

  def self.requester_user_id
    Thread.current[:requester_user_id]
  end

  def self.requester_user_id=(value)
    Thread.current[:requester_user_id] = value
  end

end