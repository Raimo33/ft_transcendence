# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    SwaggerParser.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/27 14:52:21 by craimond          #+#    #+#              #
#    Updated: 2024/10/29 14:36:26 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'openapi3_parser'
require_relative 'structs'

class SwaggerParser

  def initialize(file_path)
    @openapi_spec = Openapi3Parser.load_file(file_path)
  end

  def fill_endpoint_tree(endpoint_tree)
    @openapi_spec.paths.each do |path, path_item|
      endpoint_tree.add_path(path, process_path(path, path_item))
    end
  end

  private

  def process_path(path, path_item)
    path_item.operations.each do |http_method, operation|
      build_resource(http_method, operation)
    end
  end

  def build_resource(http_method, operation)
    Resource.new.tap do |r|
      r.http_method              = http_method
      r.expected_auth            = requires_auth?(operation)
      r.expected_request         = extract_request(operation)
      r.expected_responses       = extract_responses(operation)
      r.operation_id             = operation.operation_id
    end
  end

  def requires_auth?(operation)
    operation.security.present?
  end

  def extract_request(operation)
    ExpectedRequest.new.tap do |r|
      r.allowed_path_params   = extract_path_params(path)
      r.allowed_query_params  = extract_query_params(operation)
      r.allowed_headers       = extract_headers(operation)
      r.body_type             = extract_request_body(operation)
    end
  end

  def extract_path_params(path)
    path.scan(/\{([^}]+)\}/).flatten
  end

  def extract_query_params(operation)
    {}.tap do |query_params|
      operation.parameters.each do |parameter|
        next unless parameter.in == 'query'
  
        query_params[parameter.name.to_sym] = {
          required: parameter.required,
          style: parameter.style,
          explode: parameter.explode,
          schema: parameter.schema
        }
      end
    end
  end
  
  def extract_headers(operation)
    {}.tap do |headers|
      operation.parameters.each do |parameter|
        next unless parameter.in == 'header'
  
        headers[parameter.name.to_sym] = {
          required: parameter.required,
          style: parameter.style,
          explode: parameter.explode,
          schema: parameter.schema
        }
      end
    end
  end

  def extract_request_body(operation)
    return nil unless operation.request_body
  
    content = operation.request_body.content['application/json']
    return nil unless content
  
    {
      required: operation.request_body.required?,
      schema: content.schema
    }
  end
  

  def extract_responses(operation)
    #TODO ritorna hash di ExpectedResponse (status code, body, headers)
  end

end