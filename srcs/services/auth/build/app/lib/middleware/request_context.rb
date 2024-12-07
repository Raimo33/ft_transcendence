# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_context.rb                                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/06 20:25:23 by craimond          #+#    #+#              #
#    Updated: 2024/12/06 20:26:40 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class RequestContext

  def self.request_id
    Thread.current[:request_id]
  end

  def self.request_id=(value)
    Thread.current[:request_id] = value
  end

end