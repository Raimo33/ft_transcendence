# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ClientHandler.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/26 16:09:19 by craimond          #+#    #+#              #
#    Updated: 2024/10/27 18:02:09 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require 'async/io'
require 'async/queue'
require 'async/barrier'
require_relative 'BlockingPriorityQueue'
require_relative 'ServerExceptions'

class ClientHandler

  Request = Struct.new(:method, :path_params, :query_params, :headers, :body)
  Response = Struct.new(:status_code, :headers, :body)

  def initialize(socket, endpoint_tree)
    @stream = Async::IO::Stream.new(socket)
    @endpoint_tree = endpoint_tree
    @request_queue = Async::Queue.new
  end

  def read_requests
    buffer = String.new

    while chunk = @stream.read(4096)
      buffer << chunk

      while request = parse_request(buffer)
        @request_queue.enqueue(request)
      rescue => e
        send_error(e.status_code)
        skip_request(buffer)
      end
    end
  end

  def process_requests
    response_queue = BlockingPriorityQueue.new
    barrier = Async::Barrier.new

    Async do |task|
      response_processor = task.async do
        loop do
          response = response_queue.dequeue
          break if response == :exit_signal
          send_response(stream, response)
        rescue => e
          send_error(e.status_code)
        end
      end
      
      request_processor = task.async do
        priority = 0
        while request = @request_queue.dequeue
          current_priority = priority
          priority += 1

          barrier.async do
            grpc_request = resource.map_to_grpc_request(request)
            grpc_response = @grpc_client.call(resource.grpc_service, resource.grpc_call, grpc_request)
            response = resource.map_to_rest_response(grpc_response)
            response_queue.enqueue(current_priority, response)
          rescue => e
            send_error(e.status_code)
          end          
        end

        barrier.wait
        response_queue.enqueue(priority, :exit_signal)
      end

      [response_processor, request_processor].each(&:wait)
    end
  ensure
    barrier.stop
    request_processor.stop
    response_processor.stop
  end

  private

  def parse_request(buffer)
    request = Request.new

    header_end = buffer.index("\r\n\r\n")
    return nil unless header_end

    headers_part = buffer.slice!(0, header_end)
    body_start_index = header_end + 4

    request_line, headers_lines = headers_part.split("\r\n", 2)
    request.headers = parse_headers(headers_lines)

    content_length = headers["content-length"]&.to_i
    request.method, full_path, _ = request_line.split(" ", 3)
    path, query = full_path.split("?", 2)

    endpoint = @endpoint_tree.find_endpoint(path)
    raise ServerExceptions::NotFound unless endpoint

    resource = endpoint.resources[method]
    raise ServerExceptions::MethodNotAllowed unless resource

    if resource.body_required
      raise ServerExceptions::LengthRequired unless content_length
      raise ServerExceptions::ContentTooLarge if content_length > $MAX_BODY_SIZE
    end

    check_auth(resource, headers["authorization"])

    total_request_size = body_start_index + content_length
    return nil if buffer.size < total_request_size

    raw_body = buffer.slice!(body_start_index, content_length) if content_length > 0

    request.path_params  = parse_path_params(resource.allowed_path_params, path)
    request.query_params = parse_query_params(resource.allowed_query_params, query)
    request.body         = parse_body(resource.request_body_type, raw_body)

    request
  end
  
  def skip_request(buffer)
    until next_request_index = buffer.index(REQUEST_START_REGEX)
      buffer.clear
      more_data = @stream.read(4096)
      break unless more_data
      buffer << more_data
    end
    
    buffer.slice!(0, next_request_index) if next_request_index
  end

  def parse_headers(headers_lines)
    headers = {}

    headers_lines.split("\r\n").each do |line|
      key, value = line.split(": ", 2)
      headers[key.downcase] = value
    end

    headers
  end

  def parse_path_params(allowed_path_params, path)
    #TODO
  end

  def parse_query_params(allowed_query_params, raw_query)
    #TODO
  end

  def parse_body(request_body_type, raw_body)
    #TODO
  end

  def check_auth(resource, authorization_header)
    return unless resource.auth_required

    raise ServerExceptions::Unauthorized unless authorization_header
    raise ServerExceptions::BadRequest unless authorization_header.start_with?('Bearer ')

    token = authorization_header.split(' ')[1]&.strip
    raise ServerExceptions::Unauthorized unless jwt_validator.token_valid?(token)
  end

  def send(data)
    stream.write(data)
  end

  def send_response(response)
    #TODO
  end

  def send_error(status_code)
    #TODO switch case? map di error codes e messaggi? type check per ServerError o errori generici?
  end

end