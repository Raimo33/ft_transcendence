# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logger_interceptor.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2024/12/06 20:43:43 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../custom_logger'
require 'grpc'

class LoggerInterceptor < GRPC::ServerInterceptor

  #TODO request environvment (request_id e metadata) anche per AUTH (guardare user)

  def initialize
    @logger = CustomLogger.instance.logger
  end

  def request_response(request: nil, call: nil, method: nil)
    start_time = Time.now

    request_id = call.metadata['request_id']
    @logger.info("Received request #{request_id} on #{method.service_name}/#{method.name}")

    response = yield
    
    duration = Time.now - start_time
    @logger.info("Completed request #{request_id} in #{duration} seconds")

    response
  end

end
