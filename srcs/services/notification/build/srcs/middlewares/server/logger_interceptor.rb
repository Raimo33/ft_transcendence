# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logger_interceptor.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2024/12/06 20:32:20 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../custom_logger'
require 'grpc'

class LoggerInterceptor < GRPC::ServerInterceptor

  def initialize
    @logger = CustomLogger.instance.logger
  end

  def request_response(request: nil, call: nil, method: nil, &block)
    start_time = Time.now
    request_id = call.metadata['request_id']
    
    @logger.info("Received request #{request_id} on #{method}")

    response = yield
    
    duration = Time.now - start_time
    @logger.info("Completed request #{request_id} in #{duration} seconds")

    response
  end

end
