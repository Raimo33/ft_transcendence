# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    db_client.rb                                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2024/12/06 20:43:06 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'pg'
require 'singleton'
require_relative 'CustomLogger'
require_relative 'ConfigHandler'

class DBClient
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    db_config = @config[:database]

    @pool = PG::Pool.new(
      host:       db_config[:host],
      port:       db_config[:port],
      dbname:     db_config[:dbname],
      user:       db_config[:user],
      password:   db_config[:password],
      pool_size:  db_config.dig(:pool, :size),
      timeout:    db_config.dig(:pool, :timeout)
    )

    @logger = CustomLogger.instance.logger
  end

  def query(sql, params = [])
    with_logging do
      @pool.with do |conn|
        result = conn.exec_params(sql, params)
        rows = result.to_a
        block_given? ? yield(rows) : rows
      ensure
        result.clear
      end
    end
  end

  def transaction
    with_logging do
      @pool.with do |conn|
        conn.transaction do
          yield(conn)
        end
      end
    end
  end

  def prepare(name, sql)
    with_logging do
      @pool.with do |conn|
        conn.prepare(name, sql)
      end
    end
  end

  def exec_prepared(name, params = [])
    with_logging do
      @pool.with do |conn|
        result = conn.exec_prepared(name, params)
        rows = result.to_a
        block_given? ? yield(rows) : rows
      ensure
        result.clear
      end
    end
  end

  def stop
    @pool.close
  end

  private

  def with_logging
    start_time = Time.now
    
    request_id = Thread.current[:request_id] || 'no_request_id'
    @logger.info("Passing request #{request_id} to DB")

    result = yield

    duration = Time.now - start_time
    @logger.info("DB finished processing request #{request_id} in #{duration} seconds")

    result
  end
end