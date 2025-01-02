# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_interceptor.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2025/01/02 13:23:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'jwt'

class ExceptionInterceptor < GRPC::ServerInterceptor

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

    status_code, message = EXCEPTION_MAP[exception.class]

    if status_code.nil?
      @logger.error(exception.message)
      @logger.debug(exception.backtrace.join("\n"))
      status_code = GRPC::Core::StatusCodes::INTERNAL
      message = "Internal server error"
    end

    raise GRPC::BadStatus.new(status_code, message)
  end

end

