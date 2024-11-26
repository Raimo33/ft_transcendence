# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    db_client.rb                                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2024/11/26 19:40:41 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'pg'
require 'pgpool'
require 'singleton'
require_relative 'ConfigHandler'

class DBClient
  include Singleton

  def initialize
    @config   = ConfigHandler.instance.config
    db_config = @config[:database]

    @pool = PGPool.connect(
      host:               db_config[:host],
      port:               db_config[:port],
      dbname:             db_config[:dbname],
      user:               db_config[:user],
      password:           db_config[:password],
      max_connections:    db_config.dig(:pool, :size),
      connection_timeout: db_config.dig(:pool, :timeout)
    )
  end

  def query(sql, params: = [])
    @pool.connection do |conn|
      handle_db_call do
        result = conn.exec_params(sql, params)
        block_given? ? yield(result) : result
      end
    end
  end

  def transaction
    @pool.transaction do |conn|
      handle_db_call do
        yield(conn)
      end
    end
  end

  def prepare_and_execute(name, sql, params: = [])
    @pool.connection do |conn|
      handle_db_call do
        conn.prepare(name, sql)
        result = conn.exec_prepared(name, params)
        block_given? ? yield(result) : result
      end
    end
  end

  def stop
    @pool.close
  end
end