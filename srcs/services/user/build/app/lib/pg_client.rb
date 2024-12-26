# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    pg_client.rb                                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2024/12/26 13:27:57 by craimond         ###   ########.fr        #
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
    pg_config = @config[:postgresql]

    @pool = ConnectionPool.new(size: pg_config[:pool][:size], timeout: pg_config[:pool][:timeout]) do
      PG::Connection.new(
        host:       pg_config[:host],
        port:       pg_config[:port],
        dbname:     pg_config[:dbname],
        user:       pg_config[:user],
        password:   pg_config[:password]
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