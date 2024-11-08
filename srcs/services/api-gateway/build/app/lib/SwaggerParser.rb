# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    SwaggerParser.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/27 14:52:21 by craimond          #+#    #+#              #
#    Updated: 2024/11/08 13:06:40 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'openapi3_parser'
require_relative './modules/Structs'
require_relative './modules/ConfigLoader'
require_relative './modules/Logger'

class SwaggerParser
  include ConfigLoader
  include Logger

  def initialize(file_path)
    @logger = Logger.logger
    @logger.info('Parsing OpenAPI spec...')
    @logger.debug("OpenAPI spec file path: #{file_path}")
    @openapi_spec = Openapi3Parser.load_file(file_path)
    @logger.info('OpenAPI spec parsed')
  rescue StandardError => e
    raise "Error parsing OpenAPI spec: #{e}"
  end

  def fill_endpoint_tree(endpoint_tree)
    @openapi_spec.paths.each do |path, path_item|
      path_item.operations.each do |http_method, operation|
        endpoint_tree.add_resource(path, build_resource(http_method, operation))
      end
    end
  end

  def fill_rate_limiter(rate_limiter)
    @openapi_spec.paths.each do |path, path_item|
      path_item.operations.each do |http_method, operation|
        rate_limiter.set_limit(operation.operation_id, operation['x-ratelimit-limit'], operation['x-ratelimit-interval'], operation['x-ratelimit-criteria'])
      end
    end
  end

  private

  def build_resource(http_method, operation)
    Resource.new.tap do |r|
      r.path_template       = operation.path
      r.http_method         = http_method
      r.expected_auth_level = requires_auth?(operation)
      r.expected_request    = extract_request(operation)
      r.operation_id        = operation.operation_id
    end
  end

  def requires_auth?(operation)
    operation.security.present?
  end

  def extract_request(operation)
    ExpectedRequest.new.tap do |r|
      r.allowed_path_params   = extract_request_params(operation, 'path')
      r.allowed_query_params  = extract_request_params(operation, 'query')
      r.allowed_headers       = extract_request_params(operation, 'header')
      r.allowed_body          = extract_request_body(operation)
    end
  end

  def extract_request_params(operation, param_type)
    {}.tap do |params|
      operation.parameters.each do |param|
        next unless param.in == param_type
  
        params[param.name.to_sym] = {
          required: param.required,
          style: param.style,
          explode: param.explode,
          schema: param.schema
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

end