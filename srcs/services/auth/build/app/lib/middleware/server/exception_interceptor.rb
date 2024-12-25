# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_interceptor.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/03 13:07:24 by craimond          #+#    #+#              #
#    Updated: 2024/12/25 20:01:18 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'jwt'
require 'dalli'

class ExceptionInterceptor < GRPC::ServerInterceptor

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

    status_code, message = EXCEPTION_MAP.fetch(exception.class, nil)

    if status_code.nil?
      @logger.error(exception.message)
      @logger.debug(exception.backtrace.join("\n"))
      status_code, message = GRPC::Core::StatusCodes::INTERNAL, "Internal server error"
    end

    raise GRPC::BadStatus.new(status_code, message)
  end

end
