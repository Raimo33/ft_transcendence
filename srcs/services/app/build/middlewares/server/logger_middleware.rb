# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logger_middleware.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 11:23:17 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'openapi_first'
require_relative '../../custom_logger'
require_relative '../request_context'

class LoggerMiddleware

  def initialize(app, logger = Logger.new($stdout))
    @app = app
    @logger = CustomLogger.instance.logger
  end

  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]
    start_time = Time.now

    request_id = RequestContext.request_id
    operation_id = request.operation['operationId']
    @logger.info("Received request #{request_id} on #{operation_id}")

    status, headers, response = @app.call(env)

    duration = Time.now - start_time
    @logger.info("Completed request #{request_id} in #{duration} seconds")
    
    [status, headers, response]
  end

end