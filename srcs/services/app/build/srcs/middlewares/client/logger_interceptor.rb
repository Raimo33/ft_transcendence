# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logger_interceptor.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/03 22:14:02 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 22:16:00 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../../custom_logger'
require_relative '../../shared/request_context'

class LoggerInterceptor < GRPC::ClientInterceptor
  def initialize
    @logger = CustomLogger.instance.logger
  end

  def request_response(request: nil, call: nil, method: nil, metadata: nil)
    log_request("request", method.name) { yield request, call, method, metadata }
  end

  def client_streamer(requests: nil, call: nil, method: nil, metadata: nil)
    log_request("client stream", method.name) { yield requests, call, method, metadata }
  end

  def server_streamer(request: nil, call: nil, method: nil, metadata: nil)
    log_request("server stream", method.name) { yield request, call, method, metadata }
  end

  def bidi_streamer(requests: nil, call: nil, method: nil, metadata: nil)
    log_request("bidirectional stream", method.name) { yield requests, call, method, metadata }
  end

  private

  def log_request(type, method_name)
    request_id = RequestContext.request_id
    start_time = Time.now
    
    @logger.info("Starting gRPC #{type} #{request_id} for #{method_name}")
    
    response = yield
    
    duration = Time.now - start_time
    @logger.info("Completed gRPC #{type} #{request_id} in #{duration} seconds")
    
    response
  end
end