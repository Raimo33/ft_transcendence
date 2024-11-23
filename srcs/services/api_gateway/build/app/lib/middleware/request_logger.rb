# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_logger.rb                                  :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/23 17:30:34 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'logger'

class RequestLogger
  def initialize(app)
    @app = app
    @logger = Logger.new($stdout)
  end

  def call(env)
    request = Rack::Request.new(env)
    start_time = Time.now

    @logger.info("Started #{request.request_method} \"#{request.fullpath}\" at #{start_time}")

    status, headers, response = @app.call(env)

    end_time = Time.now
    duration = (end_time - start_time) * 1000.0

    @logger.info("Completed #{status} in #{duration.round(2)}ms")

    [status, headers, response]
  end
end

