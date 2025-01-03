# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logger_interceptor.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/03 18:26:28 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 11:25:04 by craimond         ###   ########.fr        #
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
