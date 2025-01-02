# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_interceptor.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2025/01/02 14:27:13 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'dalli'
require_relative '../../custom_logger'

class ExceptionInterceptor < GRPC::ServerInterceptor

  def initialize
    @logger = CustomLogger.instance.logger
  end

  def request_response(request: nil, call: nil, method: nil, &block)
    yield
  rescue StandardError => e
    handle_exception(e)
  end
  
  private

  CONSTRAINT_MESSAGES = {
    'pk_matchmakingpool'        => 'User already in queue',
    'fk_matchmakingpool_userid' => 'User not in queue',
  }.freeze

  EXCEPTION_MAP = {
    PG::ConnectionBad             => [GRPC::Core::StatusCodes::UNAVAILABLE, "Database connection error"],
    ConnectionPool::TimeoutError  => [GRPC::Core::StatusCodes::UNAVAILABLE, "Connection timeout"],
    Dalli::DalliError             => [GRPC::Core::StatusCodes::UNAVAILABLE, "Cache error"],
    PG::Error                     => [GRPC::Core::StatusCodes::INTERNAL, "Database error"],
  }.freeze

  def handle_exception(exception)
    raise exception if exception.is_a?(GRPC::BadStatus)
    return internal_server_error(exception) unless known_exception?(exception)

    status_code, message = case exception
    when PG::UniqueViolation
      [GRPC::Core::StatusCodes::ALREADY_EXISTS, map_constraint_violation(exception.result)]
    when PG::ForeignKeyViolation, PG::NotNullViolation, PG::CheckViolation, PG::ExclusionViolation
      [GRPC::Core::StatusCodes::INVALID_ARGUMENT, map_constraint_violation(exception.result)]
    else
      EXCEPTION_MAP[exception.class]
    end

    raise GRPC::BadStatus.new(status_code, message)
  end

  def internal_server_error(exception)
    @logger.error(exception.message)
    @logger.debug(exception.backtrace.join("\n"))
    raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INTERNAL, "Internal server error")
  end

  def known_exception?(exception)
    EXCEPTION_MAP.key?(exception.class)
  end

  def map_constraint_violation(result)
    CONSTRAINT_MESSAGES[result.constraint]
  end 

end

