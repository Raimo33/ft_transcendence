# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logger_middleware.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:02:35 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../custom_logger'
require 'openapi_first'

module Middleware

  class LoggerMiddleware

    def initialize(app, logger = Logger.new($stdout))
      @app = app
      @logger = CustomLogger.instance.logger
    end

    def call(env)
      request = env[OpenapiFirst::REQUEST]
      start_time = Time.now

      @logger.info("Started #{request.operation['operationId']}")

      status, headers, response = @app.call(env)

      end_time = Time.now
      duration = end_time - start_time
      @logger.info("Completed #{request.operation['operationId']} in #{duration} seconds")
      
      [status, headers, response]
    end

end
