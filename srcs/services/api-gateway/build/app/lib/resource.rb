# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    resource.rb                                        :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/24 16:22:25 by craimond          #+#    #+#              #
#    Updated: 2024/10/25 20:09:12 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

#acts as a Blueprint for API requests
class Resource
  attr_accessor :http_method,             # (e.g., :get, :post)
                :auth_required,           # boolean
                :grpc_service,            # identical to service name in proto file (e.g., "UserService") 
                :grpc_call,               # identical to method name in proto file (e.g., "GetUser")
                :path_template,           # Original path with parameters (e.g., "/users/{id}/posts")
                :path_params,             # Array of parameter names from path (e.g., ["id"])
                :allowed_query_params,    # Hash of query parameters
                :allowed_headers,         # Array of allowed headers
                :request_body_type,       # Hash of request body type
                :response_body_type,      # Hash of response body type
                :grpc_request_type,       # Hash of gRPC request message type
                :grpc_response_type,      # Hash of gRPC response message type
                :param_mapping,           # Detailed mapping of REST to gRPC fields
                :rate_limit_policy,       # Rate limit policy
                :cache_policy             # Cache policy

  def initialize(http_method, auth_required, endpoint...) #TODO  capire come funziona
    @http_method = http_method
    @auth_required = auth_required
    @endpoint = endpoint
  end

  def extract_path_params(path) #TODO capire come funziona
    path.scan(/\{([^}]+)\}/).flatten
  end

  def map_to_grpc_request(path_params, query_params, body)

  def map_to_rest_response(grpc_response)