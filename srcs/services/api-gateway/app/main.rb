require 'socket'
require 'json'
require_relative 'endpoint_tree.rb'
require_relative 'jwt_validator.rb'
require_relative 'grpc_client.rb'
require_relative 'response_formatter.rb'
require_relative 'helpers.rb'

begin
  EndpointTree = EndpointTreeNode.new('v1') # Root node
  EndpointTree.parse_swagger_file('app/config/API_swagger.yaml')

  jwt_validator = JwtValidator.new

  #TODO non-blocking
  server = TCPServer.new('0.0.0.0', ENV['API_GATEWAY_PORT'])

  loop do
    client = server.accept
    request_line = client.gets
    next unless request_line

    method, path, _ = request_line.split
    endpoint_node = EndpointTree.find_path(path)

    if !endpoint_node || !HttpMethod::VALID_HTTP_METHODS.include?(method.to_sym)
      return_error(client, 404, 'Invalid path or method')
      next
    end

    api_method = endpoint_node.endpoint_data[method.to_sym]
    if !api_method
      return_error(client, 405, 'Method not allowed')
      next
    end

    if api_method.auth_level != AuthLevel::NONE
      auth_header = extract_headers(client)['authorization']
      if !check_auth_header(auth_header, jwt_validator, api_method.auth_level)
        return_error(client, 401, 'Invalid or missing JWT token')
        next
      end
    end

    begin
      response = # Placeholder for gRPC service call

      client.puts "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n"
      client.puts response.to_json
    rescue StandardError => e
      return_error(client, 500, e.message)
    ensure
      client.close
    end
  end
rescue => e
  STDERR.puts "Fatal Error: #{e.message}"
end
