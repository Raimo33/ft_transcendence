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
  attr_accessor :http_method, :auth_level

  def initialize(http_method, auth_level)
    raise ArgumentError, 'Invalid HTTP method' unless HttpMethod::VALID_HTTP_METHODS.include?(http_method)
    raise ArgumentError, 'Invalid auth level' unless AuthLevel::VALID_AUTH_LEVELS.include?(auth_level)
    @http_method = http_method
    @auth_level = auth_level
  end
end

class EndpointTreeNode
  attr_accessor :segment, :children, :endpoint_data
  
  def initialize(segment)
    raise ArgumentError, 'Invalid segment' unless segment.is_a?(String)
    @segment = segment
    @children = {}
    @endpoint_data = {}
  end

  def add_path(path, api_methods)
    raise ArgumentError, 'Invalid path' unless path.is_a?(String)
    raise ArgumentError, 'Invalid api_methods' unless api_methods.is_a?(Array)

    parts = path.split('/').reject(&:empty?)
    current_node = self
  
    parts.each do |part|
    current_node.children[part] ||= EndpointTreeNode.new(part)
    current_node = current_node.children[part]
    end

    api_methods.each do |api_method|
    raise ArgumentError, 'Invalid ApiMethod' unless api_method.is_a?(ApiMethod)
    current_node.endpoint_data[api_method.http_method] = api_method
    end
  end

  # not recursive (better for shallow trees)
  def find_path(path)
    raise ArgumentError, 'Invalid path' unless path.is_a?(String)
    parts = path.split('/').reject(&:empty?)
    current_node = self
  
    parts.each do |part|
    return nil unless current_node.children[part]
    current_node = current_node.children[part]
    end

    current_node
  end

  def parse_swagger_file(file_path)
    raise ArgumentError, 'Invalid file_path' unless file_path.is_a?(String)
    require 'yaml'
    swagger_data = YAML.load_file(file_path)
    #TODO handle error (log)

    swagger_data['paths'].each do |path, methods|
      api_methods = methods.map do |http_method, details|
        auth_level = _convert_security_to_auth_level(details['security'])
        ApiMethod.new(http_method.to_sym, auth_level)
      end
      add_path(path, api_methods)
    end
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
