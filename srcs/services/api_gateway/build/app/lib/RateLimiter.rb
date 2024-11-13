# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    RateLimiter.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/05 16:52:28 by craimond          #+#    #+#              #
#    Updated: 2024/11/12 12:05:20 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class RateLimiter

  def initialize
    @limits = {}
    @strategies = {}
    @requests = Hash.new { |hash, key| hash[key] = Hash.new { |inner_hash, inner_key| inner_hash[inner_key] = [] } }
  end

  def set_limit(operation_id, limit, interval, criteria)
    @limits[operation_id] = { limit: limit, interval: interval }
    @strategies[operation_id] = criteria
  end

  def allowed?(operation_id, caller_id)
    return false unless @limits[operation_id]

    limit = @limits[operation_id][:limit]
    interval = @limits[operation_id][:interval]
    criteria = @strategies[operation_id]
    clean_up(criteria, caller_id, interval)

    if @requests[criteria][caller_id].size < limit
      @requests[criteria][caller_id] << Time.now
      true
    else
      false
    end
  end

  def get_limit(caller_id, operation_id)
    @limits[operation_id] ? @limits[operation_id][:limit] : 0
  end

  def get_remaining(caller_id, operation_id)
    return 0 unless @limits[operation_id]

    limit = @limits[operation_id][:limit]
    used = @requests[@strategies[operation_id]][caller_id].size
    [limit - used, 0].max
  end

  def get_reset(caller_id, operation_id)
    interval = @limits[operation_id] ? @limits[operation_id][:interval] : 0
    return 0 if interval.zero?

    oldest_request = @requests[@strategies[operation_id]][caller_id].first
    oldest_request ? (oldest_request + interval - Time.now).to_i : interval
  end

  def get_interval(caller_id, operation_id)
    @limits[operation_id] ? @limits[operation_id][:interval] : 0
  end

  private

  def clean_up(criteria, caller_id, interval)
    now = Time.now
    @requests[criteria][caller_id].reject! { |timestamp| timestamp < now - interval }
  end
end