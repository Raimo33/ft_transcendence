# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    SwaggerParser.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/27 14:52:21 by craimond          #+#    #+#              #
#    Updated: 2024/11/23 12:53:19 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "openapi3_parser"
require_relative "singletons/ConfigLoader"
require_relative "singletons/ConfigurableLogger"
require_relative "./modules/Structs"
require_relative "./singletons/ResourceTree"

class SwaggerParser

  def initialize(file_path)
    @logger = ConfigurableLogger.instance.logger
    @logger.info("Parsing OpenAPI spec")
    @logger.debug("OpenAPI spec file path: #{file_path}")

    @openapi_spec = Openapi3Parser.load_file(file_path)

    @logger.info("OpenAPI spec parsed")
  rescue StandardError => e
    raise "Failed to parse OpenAPI spec: #{e}"
  end

  def fill_resource_tree
    resource_tree = ResourceTree.instance
    @openapi_spec.paths.each do |path, path_item|
      path_item.operations.each do |http_method, operation|
        resource = build_resource(path, operation)
        resource_tree.add_resource(path, http_method, resource)
      end
    end
  end

  private

  def build_resource(operation)
    Resource.new.tap do |r|
      r.expected_request    = extract_operation_request(operation)
      r.operation_id        = operation.operation_id
    end
  end

  def extract_operation_request(operation)
    ExpectedRequest.new.tap do |r|
      r.allowed_path_params   = extract_operation_request_params(operation, "path")
      r.allowed_query_params  = extract_operation_request_params(operation, "query")
      r.allowed_headers       = extract_operation_request_params(operation, "header")
      r.allowed_body          = extract_operation_request_body(operation)
      r.expected_auth_level   = operation.extensions["x-auth-level"]
    end
  end

  def extract_operation_request_params(operation, param_type)
    {}.tap do |params|
      operation.parameters.each do |param|
        next unless param.in == param_type
  
        params[param.name.to_sym] = {
          required: param.required,
          style:    param.style,
          explode:  param.explode,
          schema:   param.schema
        }
      end
    end
  end

  def extract_operation_request_body(operation)
    return nil unless operation.request_body
  
    content = operation.request_body.content["application/json"]
    return nil unless content
  
    {
      required: operation.request_body.required?,
      schema:   content.schema
    }
  end

end