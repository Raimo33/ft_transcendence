require 'async'
require 'socket'
require 'json'
require_relative 'endpoint_tree'
require_relative 'jwt_validator'
require_relative 'grpc_client'
require_relative 'response_formatter'
require_relative 'helpers'
require 'async'
require 'async/io'
require 'async/queue'
require 'async/semaphore'

class AsyncServer
  def initialize(grpc_client)
    @endpoint_tree = EndpointTreeNode.new('v1')
    @endpoint_tree.parse_swagger_file('app/config/API_swagger.yaml')
    @jwt_validator = JwtValidator.new
    @grpc_client = grpc_client
    @connection_limit = Async::Semaphore.new($MAX_CONCURRENT_TASKS)
    @request_queue = Async::Queue.new
  end

  def run
    Async do |task|
      endpoint = Async::IO::Endpoint.tcp($BIND_ADDRESS, $BIND_PORT)
      
      # Start the request processor
      task.async do
        process_requests
      end
      
      # Accept connections
      endpoint.accept do |client|
        handle_client(client)
      end
    end
  end

  private

  def handle_client(client)
    Async do |subtask|
      # Limit concurrent connections
      @connection_limit.acquire do
        stream = Async::IO::Stream.new(client)
        
        while request = read_request(stream)
          method, path, headers = parse_request(request)
          
          endpoint_node, path_params, query_params = @endpoint_tree.find_path(path)
          api_method = endpoint_node&.endpoint_data&.[](method)
          
          if !api_method
            send_error(stream, 405)
            next
          end
          
          # Queue the request for processing
          @request_queue << {
            stream: stream,
            api_method: api_method,
            path_params: path_params,
            query_params: query_params,
            headers: headers
          }
        end
      end
    rescue EOFError, Async::Wrapper::Cancelled
      # Handle client disconnection
    ensure
      client.close
    end
  end

  def process_requests
    loop do
      Async do
        request = @request_queue.dequeue  # Needs async context to be non-blocking
        process_single_request(request)
      end
    end
  end

  def process_single_request(request)
    Async do
      stream = request[:stream]
      api_method = request[:api_method]
      
      if api_method.needs_auth
        unless check_auth_header(request[:headers]['authorization'], @jwt_validator)
          send_error(stream, 401, 'Invalid or missing JWT token')
          return
        end
      end

      begin
        # Transform parameters to gRPC request
        grpc_request = transform_to_grpc_request(
          request[:path_params],
          request[:query_params]
        )
        
        # Make async gRPC call
        grpc_response = await_grpc_call(api_method, grpc_request)
        
        # Transform and send response
        response = transform_grpc_response(grpc_response)
        send_response(stream, response)
      rescue StandardError => e
        send_error(stream, 500, e.message)
      end
    end
  end

  def await_grpc_call(api_method, grpc_request)
    # Wrap gRPC call in Promise for async handling
    Async do
      api_method.service.send(api_method.method, grpc_request)
    end
  end

  def read_request(stream)
    request_line = stream.gets
    return nil unless request_line
    
    headers = {}
    while line = stream.gets.strip
      break if line.empty?
      key, value = line.split(': ', 2)
      headers[key.downcase] = value
    end
    
    [request_line, headers]
  end

  def transform_to_grpc_request(path_params, query_params)
    # TODO: Implement transformation logic
    # This should create the appropriate gRPC request object
  end

  def transform_grpc_response(grpc_response)
    # TODO: Implement transformation logic
    # This should transform the gRPC response to HTTP response
  end

  def send_response(stream, response)
    stream.write("HTTP/1.1 200 OK\r\n")
    stream.write("Content-Type: application/json\r\n")
    stream.write("Content-Length: #{response.bytesize}\r\n")
    stream.write("\r\n")
    stream.write(response)
    stream.flush
  end

  def send_error(stream, code, message = nil)
    status = {
      405 => 'Method Not Allowed',
      401 => 'Unauthorized',
      500 => 'Internal Server Error'
    }[code]
    
    body = JSON.generate({
      error: status,
      message: message
    })

    stream.write("HTTP/1.1 #{code} #{status}\r\n")
    stream.write("Content-Type: application/json\r\n")
    stream.write("Content-Length: #{body.bytesize}\r\n")
    stream.write("\r\n")
    stream.write(body)
    stream.flush
  end
end