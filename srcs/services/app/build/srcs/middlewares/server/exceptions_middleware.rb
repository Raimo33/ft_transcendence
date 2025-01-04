# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    exceptions_middleware.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:24 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 19:48:20 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'jwt'
require 'json'
require 'bcrypt'
require '../shared/exceptions'

class ExceptionsMiddleware

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

  EXCEPTIONS_MAP = {
    OpenapiFirst::RequestInvalidError => [400, "Invalid request data"],
    OpenapiFirst::NotFoundError       => [404, "Resource not found"],
  }.freeze

  def handle_exception(exception)
    return http_error(exception) if exception.is_a?(HttpError)
    return known_error(exception) if known_exception?(exception)
    
    internal_server_error(exception)
  end

  def internal_server_error(exception)
    @logger.error(exception.message)
    @logger.debug(exception.backtrace.join("\n"))
    json_response(500, "Internal server error")
  end
  
  def http_error(exception)
    json_response(exception.status, exception.message)
  end
  
  def known_error(exception)
    status, message = EXCEPTIONS_MAP[exception.class]
    json_response(status, message)
  end
  
  def known_exception?(exception)
    EXCEPTIONS_MAP.key?(exception.class)
  end
  
  private
  
  def json_response(status, message)
    [status, {}, [JSON.generate(error: message)]]
  end

end
