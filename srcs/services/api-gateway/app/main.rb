require 'socket'
require 'json'
require_relative 'endpoint_tree.rb'
require_relative 'jwt_validator.rb'
require_relative 'grpc_client.rb'
require_relative 'response_formatter.rb'
require_relative 'helpers.rb'

def handle_client_request(socket, endpoint_node, api_method, jwt_validator)
  if api_method.auth_level != AuthLevel::NONE
    auth_header = extract_headers(socket)['authorization']
    unless check_auth_header(auth_header, jwt_validator, api_method.auth_level)
      return_error(socket, 401, 'Invalid or missing JWT token')
      return false
    end
  end

  begin
    response = # Placeholder for gRPC service call

    socket.puts "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n"
    socket.puts response.to_json
  rescue StandardError => e
    return_error(socket, 500, e.message)
  end

  true
end

def handle_new_client(server, clients)
  client = server.accept_nonblock
  clients << client
end

def handle_existing_client(socket, clients, jwt_validator)
  request_line = socket.gets
  if request_line
    method, path, _ = request_line.split
    endpoint_node = EndpointTree.find_path(path)

    unless endpoint_node && HttpMethod::VALID_HTTP_METHODS.include?(method.to_sym)
      return_error(socket, 404, 'Invalid path or method')
      clients.delete(socket)
      return
    end

    api_method = endpoint_node.endpoint_data[method.to_sym]
    unless api_method
      return_error(socket, 405, 'Method not allowed')
      clients.delete(socket)
      return
    end

    if handle_client_request(socket, endpoint_node, api_method, jwt_validator)
      clients.delete(socket)
      socket.close
    end
  else
    clients.delete(socket)
    socket.close
  end
end

begin
  EndpointTree = EndpointTreeNode.new('v1') # Root node
  EndpointTree.parse_swagger_file('app/config/API_swagger.yaml')

  jwt_validator = JwtValidator.new

  server = TCPServer.new('0.0.0.0', ENV['API_GATEWAY_PORT'])
  clients = []

  loop do
    readable, writeable, error = IO.select([server] + clients)

  #TODO handle writeable and error sockets (writeable solo per async?)

    readable.each do |socket|
      if socket == server
        handle_new_client(server, clients)
      else
        handle_existing_client(socket, clients, jwt_validator)
      end
    end

    # Placeholder for future handling of writable sockets
    writeable.each do |socket|
      # Future implementation
    end

    # Placeholder for future handling of error sockets
    error.each do |socket|
      # Future implementation
    end
  end
rescue => e
  STDERR.puts "Fatal Error: #{e.message}"
end
