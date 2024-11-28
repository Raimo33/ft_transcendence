# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exception_handler.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2024/11/28 04:44:18 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'json'
require 'grpc'

class ExceptionHandler
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
    # OpenapiFirst Errors
    when OpenapiFirst::RequestInvalidError
      [400, exception.message]
    when OpenapiFirst::NotFoundError
      [404, "Not Found"]
    
    # GRPC Errors
    when GRPC::InvalidArgument
      [400, exception.message]
    when GRPC::Unauthenticated
      [401, exception.message]
    when GRPC::PermissionDenied
      [403, exception.message]
    when GRPC::NotFound
      [404, exception.message]
    when GRPC::AlreadyExists
      [409, exception.message]
    when GRPC::DeadlineExceeded
      [408, exception.message]
    when GRPC::ResourceExhausted
      [429, exception.message]
    when GRPC::Unavailable
      [503, exception.message]

    # Default
    else
      @logger.error(exception.message)
      @logger.debug(exception.backtrace.join("\n"))
      [500, "Internal Server Error"]
    end

    [status, { 'Content-Type' => 'application/json' }, [{ error: message }.to_json]]
  end
end

