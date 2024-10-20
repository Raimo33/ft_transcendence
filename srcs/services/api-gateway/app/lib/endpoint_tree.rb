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
  attr_accessor :http_method, :auth_level, :is_async, :grpc_method

  def initialize(http_method, auth_level, is_async, grpc_method)
    @http_method = http_method
    @auth_level = auth_level
    @is_async = is_async
    @grpc_method = grpc_method
  end
end

class EndpointTreeNode
  attr_accessor :segment, :children, :endpoint_methods, :grpc_service

  def initialize(segment)
    @segment = segment
    @children = {}
    @endpoint_methods = {}
    @grpc_service = nil
  end

  def add_path(path, api_methods, grpc_service)
    parts = path.split('/').reject(&:empty?)
    current_node = self

    parts.each do |part|
      current_node.children[part] ||= EndpointTreeNode.new(part)
      current_node = current_node.children[part]
    end

    api_methods.each do |api_method|
      current_node.endpoint_methods[api_method.http_method] = api_method
    end

    current_node.grpc_service = grpc_service
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
        grpc_method = details['x-grpc-method']
        ApiMethod.new(http_method.to_sym, auth_level, is_async, grpc_method)
      end
      grpc_service = _extract_grpc_service(path)
      add_path(path, api_methods, grpc_service)
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

  def _extract_grpc_service(path)
    # Extract the gRPC service OBJECT based on the path
    #TODO: Implement this method
  end
end
