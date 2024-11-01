# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ClientHandler.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/26 16:09:19 by craimond          #+#    #+#              #
#    Updated: 2024/11/01 17:02:02 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require 'async/io'
require 'async/queue'
require 'async/barrier'
require_relative 'BlockingPriorityQueue'
require_relative 'ActionFailedException'
require_relative 'Mapper'
require_relative 'exceptions'
require_relative 'Logger'

class ClientHandler

  Request = Struct.new(:method, :path_params, :query_params, :headers, :body)
  Response = Struct.new(:status_code, :headers, :body)

  def initialize(socket, endpoint_tree, grpc_client, jwt_validator)
    @stream = Async::IO::Stream.new(socket)
    @endpoint_tree = endpoint_tree
    @grpc_client = grpc_client
    @jwt_validator = jwt_validator
    @request_queue = Async::Queue.new    
    @logger = Loggger.logger
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
      response_processor = task.async do |subtask|
        loop do
          response = response_queue.dequeue
          break if response == :exit_signal
          subtask.async { send_response(stream, response) }
        rescue => e
          send_error(e.status_code)
        end
      end
      
      request_processor = task.async do
        priority = 0
        while request = @request_queue.dequeue
          current_priority = priority
          priority += 1

          if request.path == "/ping"
            response_queue.enqueue(current_priority, Response.new(200, {"Content-Length" => "16"}, "pong...fumasters"))
            next
          end

          barrier.async do
            requesting_user_id = @jwt_validator.get_subject(request.headers["authorization"]) if request.headers["authorization"]
            grpc_request = Mapper.map_request_to_grpc_request(request, resource.operation_id, requesting_user_id)
            grpc_response = @grpc_client.call(grpc_request)
            response = Mapper.map_grpc_response_to_response(grpc_response, resource.operation_id)
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
    request.method, full_path, _ = request_line.split(" ", 3)
    raise ActionFailedException::BadRequest unless request.method && full_path
    raise ActionFailedException::URITooLong if full_path.size > $MAX_URI_SIZE

    path, query = full_path.split("?", 2)
    raise ActionFailedException::BadRequest unless path

    endpoint = @endpoint_tree.find_endpoint(path)
    raise ActionFailedException::NotFound unless endpoint
    
    resource = endpoint.resources[request.method]
    raise ActionFailedException::MethodNotAllowed unless resource

    expected_request = resource.expected_request

    request.headers = parse_headers(expected_request.allowed_headers, headers_lines)

    content_length = request.headers["content-length"]&.to_i

    if resource.body_required
      raise ActionFailedException::LengthRequired unless content_length
      raise ActionFailedException::ContentTooLarge if content_length > $MAX_BODY_SIZE
    end

    check_auth(resource, headers["authorization"])

    total_request_size = body_start_index + content_length
    return nil if buffer.size < total_request_size

    raw_body = buffer.slice!(body_start_index, content_length) if content_length > 0

    request.path_params  = parse_path_params(expected_request.allowed_path_params, path)
    request.query_params = parse_query_params(expected_request.allowed_query_params, query)
    request.body         = parse_body(expected_request.body_schema, raw_body)

    request
  rescue => e
    @logger.error("Error while parsing request: #{e.message}")
    raise ActionFailedException::InternalServerError
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

  def parse_headers(allowed_headers, headers_lines) #TODO valutare se implementare warning per headers non previsti
    headers = {}

    headers_lines.split("\r\n").each do |line|
      key, value = line.split(": ", 2)
      headers[key.downcase] = value
    end

    headers
  end

  def parse_path_params(allowed_path_params, path)
    return {} unless allowed_path_params
  
    path_parts = path.split("/")

    params = {}
    allowed_path_params.each_with_index do |param, index|
      next unless path_parts[index]
      params[param] = path_parts[index]
    end
  
    params
  end
  
  def parse_query_params(allowed_query_params, query)
    return {} unless allowed_query_params
  
    query_params = query.split("&")
    params = {}
  
    query_params.each do |param|
      key, value = param.split("=", 2)
      keys = key.scan(/\w+/)

      next unless allowed_query_params.include?(keys[0]) #TODO valutare se implementare warning per query params non previsti
      current = params
      keys.each_with_index do |k, index|
        if index == keys.size - 1
          current[k] = value
        else
          current[k] ||= {}
          current = current[k]
        end
      end
    end
  
    params
  end

  def parse_body(body_schema, raw_body)
    parsed_body = JSON.parse(raw_body)
    result = {}
  
    body_schema.each do |key, type|
      value = parsed_body[key.to_s]
  
      if value.is_a?(type)
        result[key] = value
      else
        raise #TODO invalid body schema error
      end
    end

    result
  rescue JSON::ParserError
    #TODO invalid json object body error
  end

  def check_auth(resource, authorization_header)
    return unless resource.auth_required

    raise ActionFailedException::Unauthorized unless authorization_header
    raise ActionFailedException::BadRequest unless authorization_header.start_with?('Bearer ')

    token = authorization_header.split(' ')[1]&.strip
    raise ActionFailedException::Unauthorized unless jwt_validator.token_valid?(token)
  end

  def send(data)
    stream.write(data)
  end

  def send_response(response)
    @logger.info("Sending response with status code #{response.status_code}")
    #TODO implementare invio risposta
  end

  def send_error(status_code)
    @logger.info("Sending response with status code #{status_code}") 
    #TODO switch case? map di error codes e messaggi? type check per ServerError o errori generici?
  end

end