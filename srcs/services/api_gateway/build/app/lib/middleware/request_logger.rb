# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_logger.rb                                  :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2024/11/28 04:42:55 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../custom_logger'

class RequestLogger
  def initialize(app, logger = Logger.new($stdout))
    @app = app
    @logger = CustomLogger.instance.logger
  end

  def call(env)
    request = Rack::Request.new(env)
    start_time = Time.now

    @logger.info("Started #{request.request_method} #{request.path}")

    status, headers, response = @app.call(env)

    end_time = Time.now
    duration = end_time - start_time
    @logger.info("Completed #{request.request_method} #{request.path} - Duration: #{duration}s")
    
    [status, headers, response]
  end

end
