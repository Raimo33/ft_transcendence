# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ClientHandler.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/26 16:09:19 by craimond          #+#    #+#              #
#    Updated: 2024/11/10 18:11:24 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "async"
require "async/io"
require "async/queue"
require "async/barrier"
require_relative "./modules/ActionFailedException"
require_relative "BlockingPriorityQueue"
require_relative "JwtValidator"
require_relative "ConfigLoader"
require_relative "ConfigurableLogger"
require_relative "Mapper"
require_relative "RequestParser"
require_relative "./modules/Structs"

class ClientHandler

  Request = Struct.new(:method, :path_params, :query_params, :headers, :body)
  Response = Struct.new(:status_code, :headers, :body)

  def initialize(socket, endpoint_tree, grpc_client, jwt_validator)
    @config         = ConfigLoader.instance.config
    @logger         = ConfigurableLogger.instance.logger
    @stream         = Async::IO::Stream.new(socket)
    @endpoint_tree  = endpoint_tree
    @grpc_client    = grpc_client
    @jwt_validator  = jwt_validator
    @request_queue  = Async::Queue.new    
  end

  def read_requests
    buffer = String.new
    parser = RequestParser.new

    while chunk = @stream.read(4096)
      buffer << chunk

      while request = parser.parse_request(buffer, @endpoint_tree, @config)
        @request_queue.enqueue(request)
      rescue StandardError => e
        @logger.error("Failed to parse request: #{e}")
        send_error(e.status_code)
        skip_request(buffer)
      end
    end
  end

  def process_requests
    response_queue = BlockingPriorityQueue.new
    barrier = Async::Barrier.new
    last_task = nil

    Async do |task|
      response_processor = task.async do |subtask|
        loop do
          begin
            response = response_queue.dequeue
            break if response == :exit_signal

            last_task&.wait
            last_task = subtask.async { send_response(stream, response) }
          rescue StandardError => e
            @logger.error("Failed to process response: #{e}")
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
            check_auth(request.expected_auth_level, request.headers["authorization"])

            if @rate_limiter.allowed?(request.caller_identifier, request.operation_id)
              grpc_request        = Mapper.map_request_to_grpc_request(request, request.operation_id, request.caller_identifier)
              grpc_response       = @grpc_client.call(grpc_request)
              response            = Mapper.map_grpc_response_to_response(grpc_response, request.operation_id)
            else
              response = Response.new(429, {"Content-Length" => "0"}, "")

            add_rate_limit_headers(response.headers, request.caller_identifier, request.path)

            response_queue.enqueue(current_priority, response)
          rescue StandardError => e
            @logger.error("Failed to process request: #{e}")
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

  def skip_request(buffer)
    until next_request_index = buffer.index(REQUEST_START_REGEX)
      buffer.clear
      more_data = @stream.read(4096)
      break unless more_data
      buffer << more_data
    end
    
    buffer.slice!(0, next_request_index) if next_request_index
  end

  def check_auth(expected_auth_level, authorization_header)
    return unless resource.expected_auth_level

    raise ActionFailedException::Unauthorized unless authorization_header

    token = extract_token(authorization_header)
    raise ActionFailedException::Unauthorized unless @jwt_validator.token_valid?(token)
    raise ActionFailedException::Forbidden unless @jwt_validator.token_authorized?(token, expected_auth_level)
  end

  def add_rate_limit_headers(headers, caller_identifier, path)
    headers["X-RateLimit-Limit"]     = @rate_limiter.limit(caller_identifier, path).to_s
    headers["X-RateLimit-Remaining"] = @rate_limiter.remaining(caller_identifier, path).to_s
    headers["X-RateLimit-Reset"]     = @rate_limiter.reset(caller_identifier, path).to_s
    headers["X-RateLimit-Interval"]  = @rate_limiter.interval(caller_identifier, path).to_s
  end

  def extract_token(authorization_header)
    raise ActionFailedException::BadRequest unless authorization_header&.start_with?("Bearer ")

    authorization_header.sub("Bearer ", "").strip
  end

  def send_response(response)
    return send_error(500) unless response
    return send_error(response.status_code) if response.status_code >= 400

    headers = response.headers.map { |k, v| "#{k}: #{v}" }.join("\r\n")
    message = Mapper::STATUS_CODE_TO_MESSAGE_MAP[response.status_code] || "OK"

    @logger.info("Sending response with status code #{response.status_code}")
    stream.write("HTTP/1.1 #{response.status_code} #{message}\r\n#{headers}\r\n\r\n#{response.body}")
  end
  
  def send_error(status_code)
    message = Mapper::STATUS_CODE_TO_MESSAGE_MAP[status_code] || "Internal Server Error"
    
    @logger.warn("Sending response with status code #{status_code}")
    stream.write("HTTP/1.1 #{status_code} #{message}\r\n\r\n")
  end

end