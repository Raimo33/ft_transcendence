require 'socket'
require 'json'
require_relative 'endpoint_tree'
require_relative 'jwt_validator'
require_relative 'grpc_client'
require_relative 'response_formatter'
require_relative 'helpers'

class Server
  def initialize
    @endpoint_tree = EndpointTreeNode.new('v1')
    @endpoint_tree.parse_swagger_file('app/config/API_swagger.yaml')
    @jwt_validator = JwtValidator.new
    @server = TCPServer.new('0.0.0.0', ENV['API_GATEWAY_PORT'])
    @clients = []
  end

  def run
    loop do
      readable, writeable, error = IO.select([@server] + @clients)

      readable.each do |socket|
        if socket == @server
          handle_new_client
        else
          handle_existing_client(socket)
        end
      end

      writeable.each do |socket|
        # Future implementation
      end

      error.each do |socket|
        # Future implementation
      end
    end
  end

  private

  def handle_new_client
    client = @server.accept_nonblock
    @clients << client
  end

  def handle_existing_client(socket)
    request_line = socket.gets
    if request_line
      method, path, _ = request_line.split
      endpoint_node = @endpoint_tree.find_path(path)

      method = method.to_sym
      unless endpoint_node && HttpMethod::VALID_HTTP_METHODS.include?(method)
        return_error(socket, 404, 'Invalid path or method')
        @clients.delete(socket)
        return
      end

      api_method = endpoint_node.endpoint_data[method]
      unless api_method
        return_error(socket, 405, 'Method not allowed')
        @clients.delete(socket)
        return
      end

      if handle_client_request(socket, endpoint_node, api_method)
        @clients.delete(socket)
        socket.close
      end
    else
      @clients.delete(socket)
      socket.close
    end
  end

  def handle_client_request(socket, endpoint_node, api_method)
    if api_method.auth_level != AuthLevel::NONE
      auth_header = extract_headers(socket)['authorization']
      unless check_auth_header(auth_header, @jwt_validator, api_method.auth_level)
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
end
