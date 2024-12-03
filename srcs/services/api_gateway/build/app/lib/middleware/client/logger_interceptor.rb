# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logger_interceptor.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/03 18:26:28 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 18:44:42 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../../custom_logger'

class LoggerInterceptor < GRPC::ClientInterceptor
  def initialize
    @logger = CustomLogger.instance.logger
  end

  def intercept(request, call, method_name, &block)
    start_time = Time.now

    request_id = call.metadata['request_id']
    @logger.info("Routing request #{request_id} to #{method_name}")

    response = yield(request, call)

    end_time = Time.now
    duration = end_time - start_time
    @logger.info("Completed request #{request_id} in #{duration} seconds")
  
    response
  end

end
