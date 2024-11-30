# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    db_client.rb                                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2024/11/30 17:11:10 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'sequel'
require 'singleton'
require_relative 'ConfigHandler'

class DBClient
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    db_config = @config[:database]

    @db = Sequel.connect(
      adapter:          'postgres',
      host:             db_config[:host],
      port:             db_config[:port],
      database:         db_config[:dbname],
      user:             db_config[:user],
      password:         db_config[:password],
      max_connections:  db_config.dig(:pool, :size),
      pool_timeout:     db_config.dig(:pool, :timeout)
    )
  end

  def query(sql, params = {})
    handle_db_call("Error executing query") do
      result = @db[sql, params].all
      block_given? ? yield(result) : result
    end
  end

  def transaction(&block)
    handle_db_call("Error during transaction") do
      @db.transaction(&block)
    end
  end

  def prepare_and_execute(name, sql, params = {})
    handle_db_call("Error executing prepared statement") do
      statement = @db[sql, params]
      result = statement.all
      block_given? ? yield(result) : result
    end
  end

  def stop
    @db.disconnect
  end

  private

  def handle_db_call(default_message = "Database error")
    yield
  rescue Sequel::Error => e
    message = e.respond_to?(:message) && !e.message.empty? ? e.message : default_message
    raise "#{default_message}: #{message}"
  end

end