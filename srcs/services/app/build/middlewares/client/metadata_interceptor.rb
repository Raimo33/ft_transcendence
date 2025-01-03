# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    metadata_interceptor.rb                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/03 22:09:49 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 22:16:55 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../../shared/request_context'

class MetadataInterceptor < GRPC::ClientInterceptor
  def request_response(request: nil, call: nil, method: nil, metadata: nil)
    handle_request(request, call, method, metadata)
  end

  def client_streamer(requests: nil, call: nil, method: nil, metadata: nil)
    handle_request(requests, call, method, metadata)
  end

  def server_streamer(request: nil, call: nil, method: nil, metadata: nil)
    handle_request(request, call, method, metadata)
  end

  def bidi_streamer(requests: nil, call: nil, method: nil, metadata: nil)
    handle_request(requests, call, method, metadata)
  end

  private

  def handle_request(req_or_reqs, call, method, metadata)
    metadata["request_id"] = RequestContext.request_id
    yield req_or_reqs, call, method, metadata
  end
end