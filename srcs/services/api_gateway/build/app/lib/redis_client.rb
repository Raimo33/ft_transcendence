# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    redis_client.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 18:03:39 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'redis'
require 'singleton'
require_relative 'CustomLogger'
require_relative 'ConfigHandler'

class DBClient
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    redis_config = @config[:redis]

    #TODO implement pool

    @logger = CustomLogger.instance.logger
  end

  #TODO implement queries

  def stop
    @pool.close
  end

  private

  def with_logging
    start_time = Time.now
    
    request_id = Thread.current[:request_id] || 'no_request_id'
    @logger.info("Passing request #{request_id} to Redis")

    result = yield

    duration = Time.now - start_time
    @logger.info("Redis finished processing request #{request_id} in #{duration} seconds")

    result
  end
end