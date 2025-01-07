# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logger_middleware.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 15:33:17 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../../custom_logger'

class LoggerMiddleware

  def initialize(app)
    @app = app
    @logger = CustomLogger.instance.logger
  end

  def call(env)
    start_time = Time.now

    request_id = RequestContext.request_id
    @logger.info("Received request #{request_id}")

    status, headers, body = @app.call(env)

    duration = Time.now - start_time
    @logger.info("Completed request #{request_id} in #{duration} seconds")
    
    [status, headers, body]
  end

end