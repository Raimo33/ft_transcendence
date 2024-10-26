# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/25 18:47:57 by craimond          #+#    #+#              #
#    Updated: 2024/10/26 08:53:44 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'set'
require 'async'
require 'async/io'
require 'async/queue'
require 'async/io/tcp_socket'
require_relative 'endpoint_tree'
require_relative 'server_exceptions'

class Server
  HTTP_METHODS_REQUIRING_BODY = %w[POST PUT PATCH].to_set
  REQUEST_START_REGEX = /^(GET|POST|PUT|PATCH|DELETE)/

  def initialize(grpc_client)
    @grpc_client = grpc_client
    @endpoint_tree = EndpointTreeNode.new('v1')
    @endpoint_tree.parse_swagger_file('/app/config/swagger.yaml')
    @clients = {}
    @request_queue = Async::Queue.new
  end

  def run
    Async do |task|
      endpoint = Async::IO::Endpoint.tcp($BIND_ADDRESS, $PORT)
      
      task.async { _process_requests }

      endpoint.accept do |client|
        task.async { _handle_client(client) }
      end
    end
  end

  private

  def _process_requests
    semaphore = Async::Semaphore.new($MAX_CONNECTIONS)

    Async do |task|
      loop do
        stream, request = @request_queue.dequeue
        semaphore.async { _handle_request(stream, request) }
      end
    end
  end

  def _handle_client(client)
    buffer = String.new
    stream = Async::IO::Stream.new(client)

    while chunk = stream.read(4096)
      buffer << chunk

      while request = _extract_request(buffer)
        @request_queue.enqueue([stream, request])
      rescue ServerExceptions::ServerError => e
        _send_error(stream, e.status_code)
      rescue => e
        _send_error(stream, 500)
    end
  end

  def _extract_request(buffer)

    HEADER_END = buffer.index("\r\n\r\n")
    return nil unless header_end

    headers_part = buffer.slice!(0, header_end)
    BODY_START_INDEX = header_end + 4
  
    request_line, headers_lines = headers_part.split("\r\n", 2)
    headers = {}
  
    headers_lines.each do |line|
      key, value = line.split(": ", 2)
      headers[key.downcase] = value
    end

    content_length = headers["content-length"]&.to_i
    method = request_line.split(" ")[0].upcase
  
    if HTTP_METHODS_REQUIRING_BODY.include?(method)
      raise LengthRequired unless content_length
      raise ContentTooLarge if content_length > $MAX_BODY_SIZE
    end

    total_request_size = body_start_index + content_length
    return nil if buffer.size < total_request_size

    body = buffer.slice!(body_start_index, content_length) if content_length > 0
    { request_line: request_line, headers: headers, body: body }
  end

  def _skip_malformed_request(buffer, stream)
    until next_request_index = buffer.index(REQUEST_START_REGEX)
      buffer.clear
      more_data = stream.read(4096)
      break unless more_data
      buffer << more_data
    end
    
    buffer.slice!(0, next_request_index) if next_request_index
  end

  def _handle_request(stream, request)
    method, path, query = _parse_request_line(request[:request_line])

    endpoint = @endpoint_tree.find_endpoint(path)
    return _send_error(stream, 404) unless endpoint

    resource = endpoint.resources[method]
    return _send_error(stream, 405) unless resource

    Async do |task|

      path_params_task = task.async { _parse_path_params(resource.path_params, path) }
      query_params_task = task.async { _parse_query_params(resource.allowed_query_params, query) }
      headers_task = task.async { _parse_headers(resource.allowed_headers, request[:headers]) }
      body_task = task.async { _parse_body(resource.request_body_type, request[:body]) }

      path_params = path_params_task.wait
      query_params = query_params_task.wait
      body = body_task.wait
      headers = headers_task.wait

      _check_auth(resource, headers)

      grpc_response @grpc_client.call(resource.grpc_service, resource.grpc_call, grpc_request)
      response = resource.map_to_rest_response(grpc_response)
      _send_response(stream, response)
    end
  end

  def _parse_request_line(request_line)
    #TODO
  end

  def _parse_path_params(path_params, path)
    #TODO
  end

  def _parse_query_params(allowed_query_params, query)
    #TODO
  end

  def _parse_headers(allowed_headers, headers)
    #TODO
  end

  def _parse_body(request_body_type, body)
    #TODO
  end

  def _check_auth(resource, headers)
    #TODO
  end

  def _send(stream, data)
    stream.write(data)
    stream.close
  end
    
  end

  def _send_response(stream, response)
    #TODO
  end

  def _send_error(stream, status_code)
    #TODO
  end