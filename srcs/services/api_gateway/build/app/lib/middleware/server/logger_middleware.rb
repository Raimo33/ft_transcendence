# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logger_middleware.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2024/12/06 20:42:24 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../../custom_logger'
require 'openapi_first'

class LoggerMiddleware

  def initialize(app, logger = Logger.new($stdout))
    @app = app
    @logger = CustomLogger.instance.logger
  end

  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]
    start_time = Time.now

    request_id = env['HTTP_X_REQUEST_ID']
    operation_id = request.operation['operationId']
    @logger.info("Received request #{request_id} on #{operation_id}")

    status, headers, response = @app.call(env)

    duration = Time.now - start_time
    @logger.info("Completed request #{request_id} in #{duration} seconds")
    
    [status, headers, response]
  end

end