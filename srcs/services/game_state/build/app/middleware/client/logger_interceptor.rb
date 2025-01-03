# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logger_interceptor.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/03 18:26:28 by craimond          #+#    #+#              #
#    Updated: 2024/12/06 20:42:03 by craimond         ###   ########.fr        #
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
    @logger.info("Passing request #{request_id} to #{method_name}")

    response = yield(request, call)

    duration = Time.now - start_time
    @logger.info("#{method_name} finished processing request #{request_id} in #{duration} seconds")
  
    response
  end

end
