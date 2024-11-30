# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_handler.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2024/11/30 11:24:00 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'json'
require 'grpc'
require 'pg'
require 'pgpool'
require_relative '../custom_logger'

class ExceptionHandler
  def initialize(app)
    @app = app
    @logger = CustomLogger.instance.logger
  end

  def call(request, call)
    @app.call(request, call)
  rescue StandardError => e
    handle_exception(e)
  end

  private

  def handle_exception(exception)
    status_code, message = case exception

     #TODO ritornare il messaggio di exception.message altrimenti default
    when GRPC::InvalidArgument
      [GRPC::Core::StatusCodes::INVALID_ARGUMENT, exception.message]
    when GRPC::Unauthenticated
      [GRPC::Core::StatusCodes::UNAUTHENTICATED, "Authentication required"]
    when GRPC::PermissionDenied
      [GRPC::Core::StatusCodes::PERMISSION_DENIED, "Permission denied"]
    when GRPC::NotFound
      [GRPC::Core::StatusCodes::NOT_FOUND, "Resource not found"]
    when GRPC::AlreadyExists
      [GRPC::Core::StatusCodes::ALREADY_EXISTS, "Resource already exists"]
    when GRPC::ResourceExhausted
      [GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED, "Resource exhausted"]
    when GRPC::FailedPrecondition
      [GRPC::Core::StatusCodes::FAILED_PRECONDITION, "Failed precondition"]
    when GRPC::Aborted
      [GRPC::Core::StatusCodes::ABORTED, "Operation aborted"]
    when GRPC::OutOfRange
      [GRPC::Core::StatusCodes::OUT_OF_RANGE, "Out of range"]
    when GRPC::Unimplemented
      [GRPC::Core::StatusCodes::UNIMPLEMENTED, "Method not implemented"]
    when GRPC::Internal
      [GRPC::Core::StatusCodes::INTERNAL, "Internal error"]
    when GRPC::Unavailable
      [GRPC::Core::StatusCodes::UNAVAILABLE, "Service unavailable"]
    when GRPC::DataLoss
      [GRPC::Core::StatusCodes::DATA_LOSS, "Data loss"]
    when GRPC::DeadlineExceeded
      [GRPC::Core::StatusCodes::DEADLINE_EXCEEDED, "Deadline exceeded"]
    when GRPC::Cancelled
      [GRPC::Core::StatusCodes::CANCELLED, "Request cancelled"]
    
    when PG::ConnectionBad
      [GRPC::Core::StatusCodes::UNAVAILABLE, "Database connection failed"]
    when PG::UniqueViolation
      [GRPC::Core::StatusCodes::ALREADY_EXISTS, "Resource already exists"]
    when PG::ForeignKeyViolation
      [GRPC::Core::StatusCodes::FAILED_PRECONDITION, "Invalid reference"]
    when PG::NotNullViolation
      [GRPC::Core::StatusCodes::INVALID_ARGUMENT, "Missing required field"]
    when PG::CheckViolation
      [GRPC::Core::StatusCodes::INVALID_ARGUMENT, "Validation failed"]
    
    when PGPool::ConnectionTimeoutError
      [GRPC::Core::StatusCodes::DEADLINE_EXCEEDED, "Database connection pool timeout"]
    when PGPool::PoolExhaustedError
      [GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED, "Database connection pool exhausted"]
    when PGPool::ConnectionCheckedOutError
      [GRPC::Core::StatusCodes::UNAVAILABLE, "Database connection unavailable"]
    when PGPool::ConnectionClosedError
      [GRPC::Core::StatusCodes::UNAVAILABLE, "Database connection closed"]
    
    else
      @logger.error(exception.message)
      @logger.debug(exception.backtrace.join("\n"))
      [GRPC::Core::StatusCodes::INTERNAL, "Internal server error"]
    end

    raise GRPC::BadStatus.new(status_code, message)
  end
end

