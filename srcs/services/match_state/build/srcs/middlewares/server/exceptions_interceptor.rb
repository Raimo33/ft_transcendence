# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exceptions_interceptor.rb                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2025/01/05 01:26:40 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../custom_logger'
require_relative '../shared/exceptions'

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
    BadRequest                    => GRPC::Core::StatusCodes::INVALID_ARGUMENT,
    Unauthorized                  => GRPC::Core::StatusCodes::UNAUTHENTICATED,
    PaymentRequired               => GRPC::Core::StatusCodes::PERMISSION_DENIED,
    Forbidden                     => GRPC::Core::StatusCodes::PERMISSION_DENIED,
    NotFound                      => GRPC::Core::StatusCodes::NOT_FOUND,
    MethodNotAllowed              => GRPC::Core::StatusCodes::UNIMPLEMENTED,
    NotAcceptable                 => GRPC::Core::StatusCodes::INVALID_ARGUMENT,
    ProxyAuthenticationRequired   => GRPC::Core::StatusCodes::UNAUTHENTICATED,
    RequestTimeout                => GRPC::Core::StatusCodes::DEADLINE_EXCEEDED,
    Conflict                      => GRPC::Core::StatusCodes::ALREADY_EXISTS,
    Gone                          => GRPC::Core::StatusCodes::NOT_FOUND,
    LengthRequired                => GRPC::Core::StatusCodes::INVALID_ARGUMENT,
    PreconditionFailed            => GRPC::Core::StatusCodes::FAILED_PRECONDITION,
    PayloadTooLarge               => GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED,
    UriTooLong                    => GRPC::Core::StatusCodes::INVALID_ARGUMENT,
    UnsupportedMediaType          => GRPC::Core::StatusCodes::INVALID_ARGUMENT,
    RangeNotSatisfiable           => GRPC::Core::StatusCodes::OUT_OF_RANGE,
    ExpectationFailed             => GRPC::Core::StatusCodes::FAILED_PRECONDITION,
    UnprocessableEntity           => GRPC::Core::StatusCodes::INVALID_ARGUMENT,
    Locked                        => GRPC::Core::StatusCodes::FAILED_PRECONDITION,
    FailedDependency              => GRPC::Core::StatusCodes::FAILED_PRECONDITION,
    TooEarly                      => GRPC::Core::StatusCodes::FAILED_PRECONDITION,
    UpgradeRequired               => GRPC::Core::StatusCodes::FAILED_PRECONDITION,
    PreconditionRequired          => GRPC::Core::StatusCodes::FAILED_PRECONDITION,
    TooManyRequests               => GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED,
    RequestHeaderFieldsTooLarge   => GRPC::Core::StatusCodes::INVALID_ARGUMENT,
    UnavailableForLegalReasons    => GRPC::Core::StatusCodes::PERMISSION_DENIED,
    InternalServerError           => GRPC::Core::StatusCodes::INTERNAL,
    NotImplemented                => GRPC::Core::StatusCodes::UNIMPLEMENTED,
    BadGateway                    => GRPC::Core::StatusCodes::UNAVAILABLE,
    ServiceUnavailable            => GRPC::Core::StatusCodes::UNAVAILABLE,
    GatewayTimeout                => GRPC::Core::StatusCodes::DEADLINE_EXCEEDED,
    HttpVersionNotSupported       => GRPC::Core::StatusCodes::UNIMPLEMENTED,
    VariantAlsoNegotiates         => GRPC::Core::StatusCodes::INTERNAL,
    InsufficientStorage           => GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED,
    LoopDetected                  => GRPC::Core::StatusCodes::ABORTED,
    NotExtended                   => GRPC::Core::StatusCodes::UNIMPLEMENTED,
    NetworkAuthenticationRequired => GRPC::Core::StatusCodes::UNAUTHENTICATED
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
    status_code = EXCEPTION_MAP[exception.class]
    GRPC::BadStatus.new(status_code, exception.message)
  end

  def known_exception?(exception)
    EXCEPTION_MAP.key?(exception.class)
  end

end

