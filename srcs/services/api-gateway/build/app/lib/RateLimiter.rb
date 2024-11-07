# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    RateLimiter.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/05 16:52:28 by craimond          #+#    #+#              #
#    Updated: 2024/11/07 18:12:38 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class RateLimiter
  def initialize
    @limits = {}
    @strategies = {}
  end

  def set_limit(operation_id, limit, period, strategy)
    @limits[operation_id] = { limit: limit, period: period }
    @strategies[operation_id] = strategy
  end

  def allowed?(caller_identifier, operation_id)
    return false unless @limits[operation_id]

    limit = @limits[operation_id][:limit]
    period = @limits[operation_id][:period]
    strategy = @strategies[operation_id]
    clean_up(strategy, caller_identifier, period)

    if @requests[strategy][caller_identifier].size < limit
      @requests[strategy][caller_identifier] << Time.now
      true
    else
      false
    end
  end

  private

  def clean_up(strategy, caller_identifier, period)
    now = Time.now
    @requests[strategy][caller_identifier].reject! { |timestamp| timestamp < now - period }
  end
end