# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    memcached_client.rb                                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 21:30:32 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'connection_pool'
require 'dalli'
require 'singleton'
require_relative 'custom_logger'
require_relative 'config_handler'
require_relative 'exceptions'
require_relative 'request_context'

class MemcachedClient
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    memcached_config = @config.dig(:memcached)
    host = memcached_config.dig(:host)
    port = memcached_config.dig(:port)
    
    @pool = ConnectionPool.new(size: memcached_config.dig(:pool, :size), timeout: memcached_config.dig(:pool, :timeout)) do
      Dalli::Client.new("#{host}:#{port}")
    end

    @logger = CustomLogger.instance.logger
  end

  def method_missing(method, *args, &block)
    with_exceptions do
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
  end

  def respond_to_missing?(method, include_private = false)
    with_exception do
      @pool.with do |conn|
        conn.respond_to?(method) || super
      end
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
    
    request_id = RequestContext.request_id
    @logger.info("Passing request #{request_id} to Memcached")

    result = yield

    duration = Time.now - start_time
    @logger.info("Memcached finished processing request #{request_id} in #{duration} seconds")

    result
  end

  def with_exceptions
    yield
  rescue Dalli::NetworkError 
    raise ServiceUnavailable.new("Cache not available")
  rescue Dalli::Error
    raise InternalServerError.new("Cache error")
  end

end