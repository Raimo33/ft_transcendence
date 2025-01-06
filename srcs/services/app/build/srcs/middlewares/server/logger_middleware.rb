# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logger_middleware.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 15:33:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'openapi_first'
require_relative '../../custom_logger'

class LoggerMiddleware

  def initialize(app)
    @app = app
    @logger = CustomLogger.instance.logger
  end

  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]
    start_time = Time.now

    request_id = RequestContext.request_id
    operation_id = parsed_request.operation["operationId"]
    @logger.info("Received request #{request_id} on #{operation_id}")

    status, headers, body = @app.call(env)

    duration = Time.now - start_time
    @logger.info("Completed request #{request_id} in #{duration} seconds")
    
    [status, headers, body]
  end

end