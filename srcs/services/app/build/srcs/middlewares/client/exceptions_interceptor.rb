# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exceptions_interceptor.rb                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/03 22:17:46 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 22:22:52 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../../shared/exceptions'

class ExceptionsInterceptor < GRPC::ClientInterceptor

  def request_response(request: nil, call: nil, method: nil, metadata: nil)
    handle_errors { yield request, call, method, metadata }
  end

  def client_streamer(requests: nil, call: nil, method: nil, metadata: nil)
    handle_errors { yield requests, call, method, metadata }
  end

  def server_streamer(request: nil, call: nil, method: nil, metadata: nil)
    handle_errors { yield request, call, method, metadata }
  end

  def bidi_streamer(requests: nil, call: nil, method: nil, metadata: nil)
    handle_errors { yield requests, call, method, metadata }
  end

  private

  ERROR_MAPPING = {
    GRPC::InvalidArgument     => BadRequest,
    GRPC::Unauthenticated     => Unauthorized,
    GRPC::PermissionDenied    => Forbidden,
    GRPC::NotFound            => NotFound,
    GRPC::AlreadyExists       => Conflict,
    GRPC::ResourceExhausted   => TooManyRequests,
    GRPC::FailedPrecondition  => PreconditionFailed,
    GRPC::Aborted             => Conflict,
    GRPC::OutOfRange          => RangeNotSatisfiable,
    GRPC::Unimplemented       => NotImplemented,
    GRPC::Unavailable         => ServiceUnavailable,
    GRPC::DeadlineExceeded    => GatewayTimeout,
    GRPC::Cancelled           => RequestTimeout,
  }.freeze

  def handle_errors
    yield
  rescue GRPC::BadStatus => e
    exception_class = ERROR_MAPPING[e.class] || InternalServerError
    raise exception_class.new(e.message)
  end
end

