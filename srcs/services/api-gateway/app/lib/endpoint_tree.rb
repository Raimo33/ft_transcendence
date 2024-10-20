# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    endpoint_tree.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:42 by craimond          #+#    #+#              #
#    Updated: 2024/10/20 16:39:27 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class ApiMethod
  attr_accessor :http_method, :auth_level, :is_async, :grpc_method_name, :grpc_service

  def initialize(http_method, auth_level, is_async, grpc_method_name, grpc_service)
    @http_method = http_method
    @auth_level = auth_level
    @is_async = is_async
    @grpc_method_name = grpc_method_name
    @grpc_service = grpc_service
  end
end

class EndpointTreeNode
  attr_accessor :segment, :children, :endpoint_methods

  def initialize(segment)
    @segment = segment
    @children = {}
    @endpoint_methods = {}
  end

  def add_path(path, api_methods)
    parts = path.split('/').reject(&:empty?)
    current_node = self

    parts.each do |part|
      current_node.children[part] ||= EndpointTreeNode.new(part)
      current_node = current_node.children[part]
    end

    api_methods.each do |api_method|
      current_node.endpoint_methods[api_method.http_method] = api_method
    end
  end

  def find_path(path)
    parts = path.split('/').reject(&:empty?)
    current_node = self
  
    parts.each do |part|
      return nil unless current_node.children[part]
      current_node = current_node.children[part]
    end

    current_node
  end

  def parse_swagger_file(file_path)
    require 'yaml'

    swagger_data = YAML.load_file(file_path)
    swagger_data['paths'].each do |path, methods|
      api_methods = methods.map do |http_method, details|
        auth_level = _convert_security_to_auth_level(details['security'])
        is_async = details['x-is-async'] || false
        grpc_method_name = details['x-grpc-method']
        grpc_service_name = details['x-grpc-service']
        grpc_service = _get_grpc_service_by_name(grpc_service_name)
        ApiMethod.new(http_method.to_sym, auth_level, is_async, grpc_method_name, grpc_service)
      end
      add_path(path, api_methods)
    end

  rescue ERRNO::ENOENT => e
    STDERR.puts "File not found: #{e.message}"
  rescue ERRNO::EACCES => e
    STDERR.puts "Permission denied: #{e.message}"
  rescue Psych::SyntaxError => e
    STDERR.puts "Error parsing YAML: #{e.message}"
  rescue StandardError => e
    STDERR.puts "Unexpected error: #{e.message}"
    nil
  end

  private

  def _convert_security_to_auth_level(security)
    return AuthLevel::NONE if security.nil? || security.empty?

    security.each do |sec|
      return AuthLevel::ADMIN if sec.key?('jwtAuth') && sec['jwtAuth'].include?('admin')
      return AuthLevel::USER if sec.key?('jwtAuth')
    end

    AuthLevel::NONE
  end

  def _get_grpc_service_by_name(service_name)
    # Implement this method to return the gRPC service object based on the service name
    # This is a placeholder implementation
    service_name
  end
end
