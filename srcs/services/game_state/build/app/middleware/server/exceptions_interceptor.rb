# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exceptions_interceptor.rb                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 17:37:34 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../custom_logger'

class ExceptionsInterceptor < GRPC::ServerInterceptor

  def initialize
    @logger = CustomLogger.instance.logger
  end

  def request_response(request: nil, call: nil, method: nil, &block)
    yield
  rescue StandardError => e
    handle_exception(e)
  end
  
  private

  EXCEPTION_MAP = {

  }.freeze

  def handle_exception(exception)
    raise exception if exception.is_a?(GRPC::BadStatus)
    raise known_error(exception) if known_exception?(exception)

    internal_server_error(exception)
  end

  def internal_server_error(exception)
    @logger.error(exception.message)
    @logger.debug(exception.backtrace.join("\n"))
    GRPC::BadStatus.new(GRPC::Core::StatusCodes::INTERNAL, "Internal server error")
  end

  def known_error(exception)
    status_code, message = EXCEPTION_MAP[exception.class]
    GRPC::BadStatus.new(status_code, message)
  end

  def known_exception?(exception)
    EXCEPTION_MAP.key?(exception.class)
  end

end

