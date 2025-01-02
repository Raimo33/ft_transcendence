# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_middleware.rb                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2025/01/02 14:33:37 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'

class ExceptionMiddleware

  def initialize(app)
    @app = app
    @logger = CustomLogger.instance.logger
  end

  def call(env)
    @app.call(env)
  rescue StandardError => e
    handle_exception(e)
  end

  private

  EXCEPTIONS_TO_STATUS_CODE = {
    OpenapiFirst::RequestInvalidError => 400,
    OpenapiFirst::NotFoundError       => 404,
    GRPC::InvalidArgument             => 400,
    GRPC::OutOfRange                  => 400,
    GRPC::Unauthenticated             => 401,
    GRPC::PermissionDenied            => 403,
    GRPC::NotFound                    => 404,
    GRPC::AlreadyExists               => 409,
    GRPC::Aborted                     => 409,
    GRPC::FailedPrecondition          => 412,
    GRPC::ResourceExhausted           => 429,
    GRPC::Cancelled                   => 499,
    GRPC::Internal                    => 500,
    GRPC::DataLoss                    => 500,
    GRPC::Unimplemented               => 501,
    GRPC::Unavailable                 => 503,
  }.freeze

  def handle_exception(exception)
    return internal_server_error(exception) unless known_exception?(exception)

    status = EXCEPTIONS_TO_STATUS_CODE[exception.class]
    message = exception.message

    [status, {}, [JSON.generate({ error: message })]]
  end

  def internal_server_error(exception)
    @logger.error(exception.message)
    @logger.debug(exception.backtrace.join("\n"))
    [500, {}, [JSON.generate({ error: "Internal server error" })]]
  end

  def known_exception?(exception)
    EXCEPTIONS_TO_STATUS_CODE.key?(exception.class)
  end

end
