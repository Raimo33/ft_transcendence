# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    pg_client.rb                                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2025/01/02 23:18:13 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'pg'
require 'connection_pool'
require 'singleton'
require_relative 'CustomLogger'
require_relative 'ConfigHandler'

class PGClient
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    pg_config = @config.fetch(:postgresql)

    @pool = ConnectionPool.new(size: pg_config.digest(:pool, :size), timeout: pg_config.dig(:pool, :timeout)) do
      PG::Connection.new(
        host:       pg_config.fetch(:host),
        port:       pg_config.fetch(:port),
        dbname:     pg_config.fetch(:dbname),
        user:       pg_config.fetch(:user),
        password:   pg_config.fetch(:password)
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

  private

  def with_logging
    start_time = Time.now
    
    request_id = Thread.current[:request_id] || 'no_request_id'
    @logger.info("Passing request #{request_id} to PostgreSQL")

    result = yield

    duration = Time.now - start_time
    @logger.info("PostgreSQL finished processing request #{request_id} in #{duration} seconds")

    result
  end
end