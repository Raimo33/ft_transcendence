# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ResourceParser.rb                                  :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/27 14:52:21 by craimond          #+#    #+#              #
#    Updated: 2024/10/27 17:57:45 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'openapi3_parser'
require_relative 'Resource'
require_relative 'EndpointTree'

class ResourceParser
  attr_reader :openapi_spec

  def initialize(openapi_path)
    barrier = Async::Barrier.new

    @openapi_spec = barrier.async { Openapi3Parser.load_file(openapi_path) }

    barrier.wait
  ensure
    barrier.stop
  end

  def fill_endpoint_tree(endpoint_tree)
    @openapi_spec.paths.each do |path, path_item|
      path_resources = process_path(path, path_item)
      endpoint_tree.add_path(path, path_resources)
    end
  end

  private

  def process_path(path, path_item)
    path_item.operations.each do |http_method, operation|
      build_resource(http_method, operation)
    end
  end

  def build_resource(http_method, operation)
    Resource.new.tap do |resource|
      resource.http_method   = http_method
      resource.auth_required = requires_auth?(operation)
      resource.request       = extract_request(operation)
      resource.responses     = extract_responses(operation)
      resource.grpc_service  = extract_grpc_service(operation)
      resource.grpc_request  = extract_grpc_request(operation)
      resource.grpc_response = extract_grpc_response(operation)
    end
  end

  def requires_auth?(operation)
    operation.security.present?
  end

  def extract_path_params(path)
    path.scan(/\{([^}]+)\}/).flatten
  end

  def extract_query_params(operation)
    #TODO: Implement logic to extract query parameters
  end  

  def extract_request_body(operation)
    #TODO: Implement logic to extract request body schema
  end

  def extract_request(operation)
    Request.new.tap do |request|
      allowed_path_params   = extract_path_params(path)
      allowed_query_params  = extract_query_params(operation)
      allowed_headers       = extract_headers(operation)
      body_type             = extract_request_body(operation)
    end
  end

  def extract_responses(operation)
    #TODO return a hash of Response.new objects keyed by status code
  end