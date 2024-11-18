# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    DBClient.rb                                        :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2024/11/18 17:45:41 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'pg'
require 'pgpool'
require_relative 'DBClientErrorHandler'
require_relative 'ConfigurableLogger'
require_relative 'ConfigLoader'

class DBClient
  include DBClientErrorHandler

  def initialize
    @config   = ConfigLoader.config
    @logger   = ConfigurableLogger.instance.logger

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

  def query(sql:, params: = [])
    @logger.debug("Executing query: #{sql}")

    @pool.connection do |conn|
      handle_db_call do
        result = conn.exec_params(sql, params)
        block_given? ? yield(result) : result
      end
    end
  end

  def transaction
    @logger.debug('Starting transaction')

    @pool.transaction do |conn|
      handle_db_call do
        yield(conn)
      end
    end
  end

  def prepare_and_execute(name:, sql:, params: = [])
    @logger.debug("Preparing and executing statement: #{sql}")

    @pool.connection do |conn|
      handle_db_call do
        conn.prepare(name, sql)
        result = conn.exec_prepared(name, params)
        block_given? ? yield(result) : result
      end
    end
  end

  def close
    @logger.info('Closing database client')

    @pool.close
  end
end