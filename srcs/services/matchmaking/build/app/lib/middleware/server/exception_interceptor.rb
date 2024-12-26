# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_interceptor.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2024/12/26 16:56:16 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'dalli'

class ExceptionInterceptor < GRPC::ServerInterceptor

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
  }.freeze

  def handle_exception(exception)
    raise exception if exception.is_a?(GRPC::BadStatus)

    status_code, message = case exception
      when PG::UniqueViolation
        [GRPC::Core::StatusCodes::ALREADY_EXISTS, map_constraint_violation(exception.result)]
      when PG::ForeignKeyViolation, PG::NotNullViolation, PG::CheckViolation, PG::ExclusionViolation
        [GRPC::Core::StatusCodes::INVALID_ARGUMENT, map_constraint_violation(exception.result)]
      else
        EXCEPTION_MAP[exception.class]
      end

    if status_code.nil?
      @logger.error(exception.message)
      @logger.debug(exception.backtrace.join("\n"))
      status_code = GRPC::Core::StatusCodes::INTERNAL
      message = "Internal server error"
    end

    raise GRPC::BadStatus.new(status_code, message)
  end

end

