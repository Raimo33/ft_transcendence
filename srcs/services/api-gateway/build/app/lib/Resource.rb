# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Resource.rb                                        :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/24 16:22:25 by craimond          #+#    #+#              #
#    Updated: 2024/10/27 17:58:00 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

#acts as a Blueprint for API requests
class Resource
  attr_accessor :http_method,             # (e.g., :get, :post)
                :auth_required,           # boolean
                :request,                 # Request object
                :responses,               # Hash of Response objects (keyed by status code)
                :grpc_service,            # identical to service name in proto file (e.g., "UserService") 
                :grpc_request,            # Hash of gRPC request message type
                :grpc_response,           # Hash of gRPC response message type

  def initialize(http_method, auth_required, request, responses, grpc_service, grpc_request, grpc_response)
    @http_method    = http_method
    @auth_required  = auth_required
    @request        = request
    @responses      = responses
    @grpc_service   = grpc_service
    @grpc_request   = grpc_request
    @grpc_response  = grpc_response
  end

end