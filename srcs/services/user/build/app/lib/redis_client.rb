# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    redis_client.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2024/12/09 21:09:37 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'redis'
require 'singleton'
require_relative 'CustomLogger'
require_relative 'ConfigHandler'

class RedisClient
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    redis_config = @config[:redis]

    @pool = ConnectionPool.new(size: redis_config[:pool][:size], timeout: redis_config[:pool][:timeout]) do
      Redis.new(
        host: redis_config[:host],
        port: redis_config[:port],
        db: redis_config[:db],
        username: redis_config[:username],
        password: redis_config[:password]
      )
    end

    @logger = CustomLogger.instance.logger
  end

  def method_missing(method, *args, &block)
    with_logging do
      @pool.with do |conn|
        if conn.respond_to?(method)
          conn.public_send(method, *args, &block)
        else
          super
        end
      end
    end
  end

  def respond_to_missing?(method, include_private = false)
    @pool.with do |conn|
      conn.respond_to?(method) || super
    end
  end

  def stop
    @pool.shutdown do |conn|
      conn.close
    end
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