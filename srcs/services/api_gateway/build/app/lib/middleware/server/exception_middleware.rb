# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_middleware.rb                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:06:25 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'json'
require 'grpc'
require 'jwt'

#TODO cacth redis errors
class ExceptionMiddleware

  GRPC_TO_HTTP_STATUS_CODE = {
    OpenapiFirst::RequestInvalidError => 400,
    GRPC::InvalidArgument             => 400,
    GRPC::OutOfRange                  => 400,
    GRPC::Unauthenticated             => 401,
    JWT::Error                        => 401,
    GRPC::PermissionDenied            => 403,
    GRPC::NotFound                    => 404,
    OpenapiFirst::NotFoundError       => 404,
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

  def handle_exception(exception)
    status = GRPC_TO_HTTP_STATUS_CODE[exception.class] || 500

    [status, {}, [JSON.generate({ error: message })]]
  end
end
