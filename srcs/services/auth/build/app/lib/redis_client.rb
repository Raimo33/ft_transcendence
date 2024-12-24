# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    redis_client.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2024/12/24 19:00:31 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'redis'
require 'singleton'
require_relative 'CustomLogger'
require_relative 'ConfigHandler'

#TODO utilizzare le pools (switchando)
class RedisClient
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    redis_config = @config[:redis]

    @pools = {}
    redis_config[:db].each do |db|
      @pools[db] = create_pool(redis_config, db)
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

  def create_pool(redis_config, db)
    ConnectionPool.new(
      size: redis_config.dig(:pool, :size),
      timeout: redis_config.dig(:pool, :timeout)
    ) do
      Redis.new(
        host: redis_config[:host],
        port: redis_config[:port],
        db: db,
        username: redis_config[:username],
        password: redis_config[:password]
      )
    end
  end

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