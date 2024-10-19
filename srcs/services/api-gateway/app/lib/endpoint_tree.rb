module HttpMethod
  GET = :GET
  POST = :POST
  PUT = :PUT
  PATCH = :PATCH
  DELETE = :DELETE

  VALID_HTTP_METHODS = [GET, POST, PUT, PATCH, DELETE].freeze
end

module AuthLevel
  NONE = :none
  USER = :user
  ADMIN = :admin

  VALID_AUTH_LEVELS = [NONE, USER, ADMIN].freeze
end

class ApiMethod
  attr_accessor :http_method, :auth_level, :is_async

  def initialize(http_method, auth_level, is_async)
    @http_method = http_method
    @auth_level = auth_level
    @is_async = is_async
  end
end

class EndpointTreeNode
  attr_accessor :segment, :children, :endpoint_data
  
  def initialize(segment)
    @segment = segment
    @children = {}
    @endpoint_data = {}
  end

  def add_path(path, api_methods)
    parts = path.split('/').reject(&:empty?)
    current_node = self
  
    parts.each do |part|
    current_node.children[part] ||= EndpointTreeNode.new(part)
    current_node = current_node.children[part]
    end

    api_methods.each do |api_method|
    current_node.endpoint_data[api_method.http_method] = api_method
    end
  end

  # not recursive (better for shallow trees)
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
        ApiMethod.new(http_method.to_sym, auth_level, is_async)
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
end
