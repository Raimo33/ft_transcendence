# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_context_interceptor.rb                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:19:58 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../request_context'

class RequestContextInterceptor < GRPC::ServerInterceptor

  def request_response(request: nil, call: nil, method: nil, &block)
    RequestContext.request_id = call.metadata['request_id'] || SecureRandom.uuid
    yield
  end

end
