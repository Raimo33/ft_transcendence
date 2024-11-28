# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_logger.rb                                  :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2024/11/28 04:42:23 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../custom_logger'

class RequestLogger
  def initialize(app)
    @app = app
    @logger = CustomLogger.instance.logger
  end

  def call(request, call)
    start_time = Time.now

    @logger.info("Started #{call.method_name} - Metadata: #{call.metadata.to_h}")

    response = @app.call(request, call)

    end_time = Time.now
    duration = end_time - start_time
    @logger.info("Completed #{call.method_name} - Metadata: #{call.metadata.to_h} - Duration: #{duration}s")
    
    response
  end

end
