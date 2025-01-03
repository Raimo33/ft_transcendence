# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    pg_client.rb                                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 16:06:03 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'pg'
require 'connection_pool'
require 'async'
require 'singleton'
require_relative 'CustomLogger'
require_relative 'ConfigHandler'

class PGClient
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    pg_config = @config.fetch(:postgresql)

    @pool = ConnectionPool.new(size: pg_config.dig(:pool, :size), timeout: pg_config.dig(:pool, :timeout)) do
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

  def prepare_statements(statements)
    barrier   = Async::Barrier.new
    semaphore = Async::Semaphore.new(@pool.size)

    with_exceptions do
      @prepared_statements.each do |name, sql|
        barrier.async do
          semaphore.acquire do
            @pg_client.prepare(name, sql)
          end
        end
      end
    end

    barrier.wait
  ensure
    barrier.stop
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
    with_exceptions do
      @pool.with do |conn|
        conn.respond_to?(method) || super
      end
    end
  end

  private

  #TODO aggiungere tutti gli altri
  CONSTRAINT_MESSAGES = {
    'pk_users'                        => 'User already exists',
    'pk_friendships'                  => 'Friendship already exists', 
    'unq_users_email'                 => 'Email already in use',
    'unq_users_displayname'           => 'Display name already in use',
    'fk_friendships_userid1'          => 'User not found',
    'fk_friendships_userid2'          => 'User not found',
    'chk_friendships_different_users' => 'Cannot be friends with yourself',
    'chk_users_email'                 => 'Invalid email format',
    'chk_users_displayname'           => 'Invalid display name format'
  }.freeze

  def with_logging
    start_time = Time.now
    
    request_id = Thread.current[:request_id] || 'no_request_id'
    @logger.info("Passing request #{request_id} to PostgreSQL")

    result = yield

    duration = Time.now - start_time
    @logger.info("PostgreSQL finished processing request #{request_id} in #{duration} seconds")

    result
  end

  def with_exceptions
    yield
  rescue PG::UniqueViolation => e
    raise Conflict.new(map_constraint_violation(e.result))
  rescue PG::NotNullViolation, PG::ForeignKeyViolation, PG::CheckViolation => e
    raise BadRequest.new(map_constraint_violation(e.result))
  rescue PG::Error
    raise InternalServerError.new('Database error')
  end

  def map_constraint_violation(result)
    constraint_name = result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    CONSTRAINT_MESSAGES[constraint_name] || "Validation error"
  end

end