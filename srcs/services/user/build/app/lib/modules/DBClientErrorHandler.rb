# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    DBClientErrorHandler.rb                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 15:50:08 by craimond          #+#    #+#              #
#    Updated: 2024/11/18 15:50:45 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative "ServerException"

require "pg"
require "pgpool"

module DBClientErrorHandler
  private

  def handle_db_call
    yield
  rescue PG::ConnectionBad, PGPool::ConnectionError => e
    @logger.error("Connection error: #{e.message}")
    raise ServerException::ServiceUnavailable.new(e.message)
  rescue PG::UndefinedTable => e
    @logger.error("Undefined table: #{e.message}")
    raise ServerException::NotFound.new(e.message)
  rescue PG::UndefinedColumn => e
    @logger.error("Undefined column: #{e.message}")
    raise ServerException::BadRequest.new(e.message)
  rescue PG::UniqueViolation => e
    @logger.error("Unique constraint violation: #{e.message}")
    raise ServerException::Conflict.new(e.message)
  rescue PG::CheckViolation => e
    @logger.error("Check constraint violation: #{e.message}")
    raise ServerException::BadRequest.new(e.message)
  rescue PG::ForeignKeyViolation => e
    @logger.error("Foreign key constraint violation: #{e.message}")
    raise ServerException::BadRequest.new(e.message)
  rescue PG::NotNullViolation => e
    @logger.error("Not null constraint violation: #{e.message}")
    raise ServerException::BadRequest.new(e.message)
  rescue PG::SyntaxError => e
    @logger.error("SQL syntax error: #{e.message}")
    raise ServerException::BadRequest.new(e.message)
  rescue PG::InvalidTextRepresentation => e
    @logger.error("Invalid text representation: #{e.message}")
    raise ServerException::BadRequest.new(e.message)
  rescue PG::InsufficientPrivilege => e
    @logger.error("Insufficient database privilege: #{e.message}")
    raise ServerException::Forbidden.new(e.message)
  rescue PG::QueryCanceled, PG::StatementTimeout => e
    @logger.error("Query canceled or timed out: #{e.message}")
    raise ServerException::RequestTimeout.new(e.message)
  rescue PG::ConnectionException => e
    @logger.error("PostgreSQL connection exception: #{e.message}")
    raise ServerException::ServiceUnavailable.new(e.message)
  rescue PGPool::TimeoutError => e
    @logger.error("Connection pool timeout: #{e.message}")
    raise ServerException::ServiceUnavailable.new(e.message)
  rescue PG::FeatureNotSupported => e
    @logger.error("Unsupported database feature: #{e.message}")
    raise ServerException::BadRequest.new(e.message)
  rescue PG::DataException => e
    @logger.error("Data processing error: #{e.message}")
    raise ServerException::BadRequest.new(e.message)
  rescue PG::IntegrityConstraintViolation => e
    @logger.error("Integrity constraint violation: #{e.message}")
    raise ServerException::Conflict.new(e.message)
  rescue PG::InvalidAuthorizationSpecification => e
    @logger.error("Invalid authorization specification: #{e.message}")
    raise ServerException::Unauthorized.new(e.message)
  rescue PG::Error => e
    @logger.error("Unhandled PostgreSQL error: #{e.message}")
    raise ServerException::InternalServer.new(e.message)
  rescue StandardError => e
    @logger.error("Unexpected error: #{e.message}")
    raise ServerException::InternalServer.new(e.message)
  end
end