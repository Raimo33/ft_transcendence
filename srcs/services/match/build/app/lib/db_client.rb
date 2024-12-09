# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    db_client.rb                                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 20:24:05 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'pg'
require 'connection_pool'
require 'singleton'
require_relative 'CustomLogger'
require_relative 'ConfigHandler'

class DBClient
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    db_config = @config[:database]

    @pool = ConnectionPool.new(size: db_config[:pool][:size], timeout: db_config[:pool][:timeout]) do
      PG::Connection.new(
        host:       db_config[:host],
        port:       db_config[:port],
        dbname:     db_config[:dbname],
        user:       db_config[:user],
        password:   db_config[:password]
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