# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    db_client.rb                                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2024/11/25 17:43:09 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'pg'
require 'pgpool'
require 'singleton'
require_relative 'DBClientErrorHandler'
require_relative 'ConfigHandler'

class DBClient
  include Singleton
  include DBClientErrorHandler

  def initialize
    @config   = ConfigHandler.instance.config

    @pool = PGPool.connect(
      host:               @config[:database][:host],
      port:               @config[:database][:port],
      dbname:             @config[:database][:dbname],
      user:               @config[:database][:user],
      password:           @config[:database][:password],
      max_connections:    @config[:database][:pool][:size],
      connection_timeout: @config[:database][:pool][:timeout]
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