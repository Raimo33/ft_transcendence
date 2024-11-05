# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    RateLimiter.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/05 16:52:28 by craimond          #+#    #+#              #
#    Updated: 2024/11/05 17:22:18 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

#TODO capire

class RateLimiter
  def initialize
    @limits = {}
    @requests = Hash.new { |hash, key| hash[key] = [] }
  end

  def set_limit(endpoint, limit, period)
    @limits[endpoint] = { limit: limit, period: period }
  end

  def allowed?(client_id, endpoint)
    return false unless @limits[endpoint]

    limit = @limits[endpoint][:limit]
    period = @limits[endpoint][:period]
    clean_up(client_id, period)
    
    if @requests[client_id].size < limit
      @requests[client_id] << Time.now
      true
    else
      false
    end
  end

  private

  def clean_up(client_id, period) #TODO capire
    now = Time.now
    @requests[client_id].reject! { |timestamp| timestamp < now - period }
  end
end
