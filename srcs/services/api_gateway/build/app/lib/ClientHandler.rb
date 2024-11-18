# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ClientHandler.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/26 16:09:19 by craimond          #+#    #+#              #
#    Updated: 2024/11/18 19:25:26 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "async"
require "async/io"
require "async/queue"
require "async/barrier"
require_relative "BlockingPriorityQueue"
require_relative "JwtValidator"
require_relative "ConfigLoader"
require_relative "ConfigurableLogger"
require_relative "RequestParser"
require_relative "./modules/ServerException"
require_relative "./modules/Structs"
require_relative "./modules/Mapper"

class ClientHandler

  STATUS_CODE_TO_MESSAGE_MAP = {
    200 => "OK",
    201 => "Created",
    204 => "No Content",
    304 => "Not Modified",
    400 => "Bad Request",
    401 => "Unauthorized",
    403 => "Forbidden",
    404 => "Not Found",
    405 => "Method Not Allowed",
    408 => "Request Timeout",
    409 => "Conflict",
    429 => "Too Many Requests",
    500 => "Internal Server Error",
    501 => "Not Implemented",
    502 => "Bad Gateway",
    503 => "Service Unavailable",
    504 => "Gateway Timeout"
  }.freeze

  BUFFER_SIZE = 4096
  READ_SIZE   = 1024

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
    buffer = String.new(capacity: BUFFER_SIZE)
    parser = RequestParser.new(@endpoint_tree)

    while chunk = @stream.read(READ_SIZE)
      buffer << chunk

      while request = parser.parse_request(buffer)
        @request_queue.enqueue(request)
      rescue StandardError => e
        @logger.error("Failed to parse request: #{e}")
        send_error(e.status_code)
      end
    end
  end

  def process_requests #TODO ricerchera la request.path nell resource tree per fare i check del caso anche rispetto ad expected request
    response_queue = BlockingPriorityQueue.new
    barrier        = Async::Barrier.new
    last_task      = nil

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
            check_auth(request.resource.expected_auth_level, request.headers[:authorization])

            grpc_response = @grpc_client.send(request)
            response = #TODO parse da grpc a http

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

  def check_auth(expected_auth_level, authorization_header)
    raise ServerException::Unauthorized unless authorization_header

    token = extract_token(authorization_header)
    raise ServerException::Unauthorized unless @jwt_validator.token_valid?(token)
    raise ServerException::Forbidden    unless @jwt_validator.token_authorized?(token, expected_auth_level)
  end

  def extract_token(authorization_header)
    raise ServerException::BadRequest unless authorization_header&.start_with?("Bearer ")

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