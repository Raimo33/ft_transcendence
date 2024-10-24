#TODO add requires

class Server
  def initialize(grpc_client)
    @endpoint_tree = EndpointTreeNode.new('v1')
    @endpoint_tree.parse_swagger_file('app/config/API_swagger.yaml')
    @jwt_validator = JwtValidator.new
    @grpc_client = grpc_client
    @connection_limit = Async::Semaphore.new($MAX_CONNECTIONS)
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

    def _handle_client(client)
      Async do |subtask|
        @connection_limit.acquire do
          socket_stream = Async::IO::Stream.new(client)
          buffer = Async::IO::Buffer.new

          loop do #TODO blocking operation, capire se si puo rendere async anche se legge dallo stesso stream
            request, buffer = _read_request(socket_stream, buffer)
            @request_queue.enqueue(request)
          end
        end

      rescue EOFError, Async::Wrapper::Cancelled
        # TODO Handle client disconnection
      ensure
        client.close
      end
    end

  def _process_requests
    loop do
      Async do
        request = @request_queue.dequeue
        _process_single_request(request)
      end
    end
  end

  def _process_single_request(request)
    Async do
      begin
        method, path, query, headers_raw, body_raw = _parse_request(request)

        endpoint_node = @endpoint_tree.find_path(path)
        return _send_error(socket_stream, 404) unless endpoint_node

        resource = endpoint_node&.endpoint_data&.[](method)
        return _send_error(socket_stream, 405) unless resource

        headers = parse_headers(resource.allowed_headers, headers_raw)
        if resource.auth_required
          auth_header = headers['authorization']
          return _send_error(socket_stream, 400) unless auth_header&.start_with?('Bearer ')
          token = auth_header.split(' ')[1]
          return _send_error(socket_stream, 401) unless jwt_validator.validate(token)
        end
        if resource.request_body_type
          content_length = headers['content-length']&.to_i
          return _send_error(socket_stream, 411) unless content_length
          return _send_error(socket_stream, 413) unless content_length.between?(0, $MAX_BODY_SIZE)
          body = parse_body(resource.request_body_type, body_raw, content_length)
        end
        else
          body = nil
        end

        path_params = _parse_path_params(resource.path_params, path)
        query_params = _parse_query_params(resource.query_params, query)

        grpc_request = resource.map_to_grpc_request(path_params, query_params, body)
        grpc_response = await_grpc_call(api_method, grpc_request)
        rest_response = resource.map_to_rest_response(grpc_response)

        _send_response(socket_stream, rest_response)
      rescue StandardError => e
        _send_error(socket_stream, 500, e.message)
      end
    end
  end

  def _read_request(socket_stream, buffer)


  def _parse_request(request)
  
    #TODO: Implement
  end

  def _await_grpc_call(api_method, grpc_request)
    Async do
      api_method.service.send(api_method.method, grpc_request)
    end
  end

  def _send_response(socket_stream, response)
    #TODO: Implement
  end

  def _send_error(socket_stream, code, message = nil)
    #TODO: implement
  end

end