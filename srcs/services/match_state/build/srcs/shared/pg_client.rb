# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    pg_client.rb                                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:46:21 by craimond          #+#    #+#              #
#    Updated: 2025/01/05 18:08:26 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'pg'
require 'connection_pool'
require 'async'
require 'singleton'
require_relative 'custom_logger'
require_relative 'config_handler'

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

  def stop
    @pool.shutdown do |conn|
      conn.cancel if conn.status == PG::CONNECTION_BUSY
      conn.block if conn.is_busy
      conn.finish
    end rescue nil

    @logger.info('PostgreSQL connection pool stopped')
  end

  private

  CONSTRAINT_MESSAGES = {
    'pk_users'                          => 'User already exists',
    'unq_users_email'                   => 'Email already in use',
    'unq_users_displayname'             => 'Display name already in use',
    'chk_users_email'                   => 'Invalid email format',
    'chk_users_displayname'             => 'Invalid display name format',
    'chk_users_avatar'                  => 'Invalid avatar format',
    'pk_matches'                        => 'Match already exists',
    'fk_matches_tournamentid'           => 'Tournament not found',
    'unq_matches_tournamentid'          => 'Tournament already has a match',
    'chk_matches_startedat'             => 'Invalid start time',
    'chk_matches_endedat'               => 'Invalid end time',
    'pk_tournaments'                    => 'Tournament already exists',
    'fk_tournaments_creatorid'          => 'Creator not found',
    'chk_tournaments_startedat'         => 'Invalid start time',
    'chk_tournaments_endedat'           => 'Invalid end time',
    'pk_friendships'                    => 'Friendship already exists',
    'fk_friendships_userid1'            => 'User not found',
    'fk_friendships_userid2'            => 'User not found',
    'chk_friendships_different_users'   => 'Cannot be friends with yourself',
    'pk_matchplayers'                   => 'Player already in match',
    'fk_matchplayers_matchid'           => 'Match not found',
    'fk_matchplayers_userid'            => 'User not found',
    'pk_tournamentplayers'              => 'Player already in tournament',
    'fk_tournamentplayers_tournamentid' => 'Tournament not found',
    'fk_tournamentplayers_userid'       => 'User not found',
    'pk_matchmakingpool'                => 'Player already in matchmaking pool',
    'fk_matchmakingpool_userid'         => 'User not found',
    'chk_matchmakingpool_addedat'       => 'Invalid add time',
  }.freeze

  def with_logging
    start_time = Time.now
    
    request_id = RequestContext.request_id
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