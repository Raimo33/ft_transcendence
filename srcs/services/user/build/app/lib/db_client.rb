# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    db_client.rb                                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 13:38:20 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'pg'
require 'singleton'
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
  end

  def query(sql, params = [])
    @pool.with do |conn|
      result = conn.exec_params(sql, params)
      rows = result.to_a
      block_given? ? yield(rows) : rows
    ensure
      result.clear
    end
  end

  def transaction
    @pool.with do |conn|
      conn.transaction do
        yield(conn)
      end
    end
  end

  def prepare(name, sql)
    @pool.with do |conn|
      conn.prepare(name, sql)
    end
  end

  def exec_prepared(name, params = [])
    @pool.with do |conn|
      result = conn.exec_prepared(name, params)
      rows = result.to_a
      block_given? ? yield(rows) : rows
    ensure
      result.clear
    end
  end

  def stop
    @pool.close
  end

end