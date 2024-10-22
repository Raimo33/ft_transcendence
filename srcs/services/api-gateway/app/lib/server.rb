require 'async'
require 'socket'
require 'json'
require_relative 'endpoint_tree'
require_relative 'jwt_validator'
require_relative 'grpc_client'
require_relative 'response_formatter'
require_relative 'helpers'

#TODO rivedere async e come funziona

class Server
  def initialize
    @endpoint_tree = EndpointTreeNode.new('v1')
    @endpoint_tree.parse_swagger_file('app/config/API_swagger.yaml')
    @jwt_validator = JwtValidator.new
    @server = TCPServer.new($BIND_ADDRESS, $BIND_PORT)
    @clients = []
    @responses = {}
  end

  def run
    loop do
      readable, writable, broken = IO.select([@server] + @clients, @clients, @clients)

      Async do
        _handle_readable(readable)
      end

      Async do
        _handle_writeable(writable)
      end

      Async do
        _handle_broken(broken)
      end
    end
  end

  def stop
    @clients.each(&:close)
    @server.close
  end

  private

  def _handle_readable(readable)
    readable.each do |socket|
      if socket == @server
        _handle_new_client
      else
        Async do
          _handle_existing_client(socket)
        end
      end
    end
  end

  def _handle_writeable(writable)
    writable.each do |socket|
      response = @responses.delete(socket)
      if response
        send_response(socket, response)
      end
    end
  end

  def _handle_broken(broken)
    broken.each do |socket|
      @clients.delete(socket)
      socket.close
      @responses.delete(socket)
      _handle_socket_error(socket)
    end
  end

  def _handle_new_client
    client = @server.accept_nonblock
    @clients << client
  end

  def _handle_existing_client(socket)
    request_line = socket.gets
    if request_line
      method, path, _ = request_line.split
      endpoint_node, path_params, query_params = @endpoint_tree.find_path(path)

      api_method = endpoint_node.endpoint_data[method]
      unless api_method
        send_error(socket, 405)
        return
      end

      _handle_client_request(socket, api_method, path_params, query_params)
    end
  end

  def _handle_client_request(socket, api_method, path_params, query_params)
    headers = extract_headers(socket)
    _check_auth(socket, api_method, headers['authorization'])
  
    grpc_request = # TODO transform to gRPC request
  
    # Use an asynchronous block to handle the gRPC request
    Async do
      begin
        grpc_response = api_method.service.send(api_method.method, grpc_request)
        response = # TODO transform gRPC response to REST response
        @responses[socket] = response
      rescue StandardError => e
        send_error(socket, 500)  # Send error response to the client
      end
    end
  
    true
  end

  def _check_auth(socket, api_method, auth_header)
    if api_method.auth_level != AuthLevel::NONE
      send_error(socket, 401, 'Invalid or missing JWT token') unless check_auth_header(auth_header, @jwt_validator, api_method.auth_level)
    end
  end

end
