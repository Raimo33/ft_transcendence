class ApiMethod
  attr_accessor :http_method, :auth_level, :grpc_message

  def initialize(http_method, auth_level, grpc_message)
    @http_method = http_method
    @auth_level = auth_level
    @grpc_message = grpc_message #TODO trovare il modo di mappare method e grpc_message
  end
end

class EndpointTreeNode
  attr_accessor :part, :children, :endpoint_methods

  def initialize(part)
    @part = part
    @children = {}
    @endpoint_methods = {}
  end

  def add_path(path, api_methods)
    parts = path.split('/').reject(&:empty?)
    current_node = self

    parts.each do |part|
      current_node.children[part] ||= EndpointTrieNode.new(part)
      current_node = current_node.children[part]
    end

    api_methods.each do |api_method|
      current_node.endpoint_methods[api_method.http_method] = api_method
    end
  end

  def find_path(path)
    path, query_string = path.split('?', 2)
    parts = path.split('/').reject(&:empty?)
    current_node = self
    path_params = {}
    query_params = {}

    parts.each do |part|
      if current_node.children[part]
        # Exact match (literal segment)
        current_node = current_node.children[part]
      else
        variable_node = current_node.children.find do |key, _|
          key.start_with?('{') && key.end_with?('}')
        end

        if variable_node
          # Matched a variable segment
          variable_name = variable_node[0][1..-2]
          path_params[variable_name] = part
          current_node = variable_node[1]
        else
          # No match
          return nil
        end
      end
    end

    if query_string
      query_string.split('&').each do |param|
        key, value = param.split('=', 2)
        query_params[key] = value
      end
    end

    # Return the current node along with matched variables and query parameters
    return current_node, path_params, query_params
  end

  def parse_swagger_file(file_path)
    require 'yaml'

    swagger_data = YAML.load_file(file_path)
    swagger_data['paths'].each do |path, methods|
      api_methods = methods.map do |http_method, details|
        needs_auth = details['security']
        grpc_message = details['operationId']
        ApiMethod.new(http_method.to_sym, auth_level, is_async, grpc_message)
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

end
