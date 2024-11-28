# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_handler.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2024/11/28 04:51:15 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'json'
require 'grpc'
require 'pg'
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
    # GRPC Errors
    when GRPC::InvalidArgument
      [GRPC::Core::StatusCodes::INVALID_ARGUMENT, exception.message]
    when GRPC::Unauthenticated
      [GRPC::Core::StatusCodes::UNAUTHENTICATED, "Authentication required"]
    when GRPC::PermissionDenied
      [GRPC::Core::StatusCodes::PERMISSION_DENIED, "Permission denied"]
    when GRPC::NotFound
      [GRPC::Core::StatusCodes::NOT_FOUND, "Resource not found"]
    
    # Database Errors
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
    
    # Pool Errors
    when ConnectionPool::PoolTimeout
      [GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED, "Database pool exhausted"]
    
    # Default
    else
      @logger.error(exception.message)
      @logger.debug(exception.backtrace.join("\n"))
      [GRPC::Core::StatusCodes::INTERNAL, "Internal server error"]
    end

    raise GRPC::BadStatus.new(status_code, message)
  end
end

