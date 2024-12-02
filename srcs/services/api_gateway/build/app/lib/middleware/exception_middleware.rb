# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_middleware.rb                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 19:47:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'json'
require 'grpc'
require 'jwt'

module Middleware

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

    def handle_exception(exception)
      status, message = case exception

      when OpenapiFirst::RequestInvalidError
        [400, exception.message]
      when OpenapiFirst::NotFoundError
        [404, "Not Found"]

      when JWT::Error
        [401, exception.message]
      
      when GRPC::InvalidArgument, GRPC::OutOfRange
        [400, exception.message]
      when GRPC::Unauthenticated
        [401, exception.message]
      when GRPC::PermissionDenied
        [403, exception.message]
      when GRPC::NotFound
        [404, exception.message]
      when GRPC::DeadlineExceeded
        [408, exception.message]
      when GRPC::AlreadyExists, GRPC::Aborted
        [409, exception.message]
      when GRPC::FailedPrecondition
        [412, exception.message]
      when GRPC::ResourceExhausted
        [429, exception.message]
      when GRPC::Cancelled
        [499, exception.message]
      when GRPC::Internal, GRPC::DataLoss
        [500, exception.message]
      when GRPC::Unimplemented
        [501, exception.message]
      when GRPC::Unavailable
        [503, exception.message]

      else
        @logger.error(exception.message)
        @logger.debug(exception.backtrace.join("\n"))
        [500, "Internal Server Error"]
      end

      [status, {}, [JSON.generate({ error: message })]]
    end
  end

end