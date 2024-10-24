#TODO add requires

class AsyncServer
  def initialize(grpc_client)
    @endpoint_tree = EndpointTreeNode.new('v1')
    @endpoint_tree.parse_swagger_file('app/config/API_swagger.yaml')
    @jwt_validator = JwtValidator.new
    @grpc_client = grpc_client
    @connection_limit = Async::Semaphore.new($CONNECTION_LIMIT)
    @request_queue = Async::Queue.new
  end

  def run
    Async do |task|
      endpoint = Async::IO::Endpoint.tcp($BIND_ADDRESS, $BIND_PORT)
      
      task.async do
        process_requests
      end
      
      endpoint.accept do |client|
        handle_client(client)
      end
    end
  end

  private

    def handle_client(client)
      Async do |subtask|
        @connection_limit.acquire do
          stream = Async::IO::Stream.new(client)
          
          while request = read_request(stream)
            method, full_path, headers = parse_request(request)

            path, query_string = full_path.split('?')
            endpoint_node = @endpoint_tree.find_path(path)
            if !endpoint_node
              send_error(stream, 404)
              next
            end

            api_request = endpoint_node&.endpoint_data&.[](method)
            if !api_request
              send_error(stream, 405)
              next
            end

            if api_request.auth_required
              #TODO: Implement JWT validation

            content_length = headers['content-length']&.to_i
            if content_length.nil? || content_length < 0
              send_error(stream, 411)
              next
            end

            if content_length > $MAX_BODY_SIZE
              send_error(stream, 413)
              next
            end

            @request_queue << {
              stream: stream,
              api_request: api_request, 
              path: path,
              query_string: query_string,
              headers: headers
            }

          end
        end
      rescue EOFError, Async::Wrapper::Cancelled
        # TODO Handle client disconnection
      ensure
        client.close
      end
    end

  def process_requests
    loop do
      Async do
        request = @request_queue.dequeue
        process_single_request(request)
      end
    end
  end

  def process_single_request(request)
    Async do
      stream = request[:stream]
      api_request = request[:api_request]

      
      begin
        
        body_task = subtask.async do
            extract_body(stream, content_length)
          end
        end

        path_params = parse_path_params(api_request.path_template, request[:path]) #TODO, valutare se includerla in qualche classe
        query_params = parse_query_params(api_request.query_params, request[:query_string]) #TODO, valutare se includerla in qualche classe
        body = body_task.wait

        grpc_request = api_request.map_to_grpc_request(
        grpc_response = await_grpc_call(api_method, grpc_request)
        rest_response = api_request.map_to_rest_response(grpc_response)

        send_response(stream, rest_response)
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

    #TODO: Implement
  end

  def send_response(stream, response)
    #TODO: Implement
  end

  def send_error(stream, code, message = nil)
    #TODO: implement
  end
end