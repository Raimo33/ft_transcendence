# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_interceptor.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/03 13:07:24 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 13:56:50 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'

class ExceptionInterceptor < GRPC::ServerInterceptor

  def request_response(request: nil, call: nil, method: nil)
    yield
  rescue StandardError => e
    handle_exception(e)
  end

  private

  def handle_exception(exception)
    raise exception if exception.is_a?(GRPC::BadStatus)

    status_code, message = case exception

    when JWT::DecodeError
      [GRPC::Core::StatusCodes::UNAUTHENTICATED, "Invalid token"]
    else
      @logger.error(exception.message)
      @logger.debug(exception.backtrace.join("\n"))
      [GRPC::Core::StatusCodes::INTERNAL, "Internal server error"]

    raise GRPC::BadStatus.new(status_code, message)
  end

end
