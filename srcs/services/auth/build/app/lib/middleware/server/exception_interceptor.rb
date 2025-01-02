# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_interceptor.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/03 13:07:24 by craimond          #+#    #+#              #
#    Updated: 2025/01/02 14:23:23 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'jwt'
require 'dalli'
require_relative '../../custom_logger'

class ExceptionInterceptor < GRPC::ServerInterceptor

  def initialize
    @logger = CustomLogger.instance.logger
  end

  def request_response(request: nil, call: nil, method: nil)
    yield
  rescue StandardError => e
    handle_exception(e)
  end

  private

  EXCEPTION_MAP = {
    JWT::DecodeError  => [GRPC::Core::StatusCodes::UNAUTHENTICATED, "Invalid token"],
    Dalli::DalliError => [GRPC::Core::StatusCodes::UNAVAILABLE, "Cache error"],
  }.freeze

  def handle_exception(exception)
    raise exception if exception.is_a?(GRPC::BadStatus)
    return internal_server_error(exception) unless known_exception?(exception)

    status, message = EXCEPTION_MAP[exception.class]
    GRPC::BadStatus.new(status, message)
  end

  def internal_server_error(exception)
    @logger.error(exception.message)
    @logger.debug(exception.backtrace.join("\n"))
    GRPC::BadStatus.new(GRPC::Core::StatusCodes::INTERNAL, "Internal server error")
  end

  def known_exception?(exception)
    EXCEPTION_MAP.key?(exception.class)
  end

end
