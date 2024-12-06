# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_context_interceptor.rb                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2024/12/06 20:26:06 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../request_context'

class RequestContextInterceptor < GRPC::ServerInterceptor

  def request_response(request: nil, call: nil, method: nil, &block)
    start_time = Time.now
    RequestContext.request_id = call.metadata['request_id'] || SecureRandom.uuid
    
    yield
  end

end
