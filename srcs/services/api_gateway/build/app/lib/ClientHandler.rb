# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ClientHandler.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/26 16:09:19 by craimond          #+#    #+#              #
#    Updated: 2024/11/23 12:01:00 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "async"
require "async/io"
require "async/queue"
require "async/barrier"
require_relative "BlockingPriorityQueue"
require_relative "JwtValidator"
require_relative "singletons/ConfigLoader"
require_relative "singletons/ConfigurableLogger"
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

  def initialize(socket)
    @config            = ConfigLoader.instance.config
    @logger            = ConfigurableLogger.instance.logger
    @endpoint_tree     = EndpointTree.instance
    @grpc_client       = GrpcClient.instance
    @request_validator = RequestValidator.instance
    
    @stream            = Async::IO::Stream.new(socket)
    @request_queue     = Async::Queue.new
    @response_queue    = BlockingPriorityQueue.new 
  end

  def read_requests
    buffer = String.new(capacity: BUFFER_SIZE)
    parser = RequestParser.new

    while chunk = @stream.read(READ_SIZE)
      buffer << chunk

      while request = parser.parse_request(buffer)
        @request_queue.enqueue(request)
      rescue StandardError => e
        @logger.error("Failed to parse request: #{e}")
        send_error(e.status_code)
        parser.skip_request(buffer)
      end
    end
  end

  def process_requests
    barrier = Async::Barrier.new

    barrier.async { send_responses }
    barrier.async { fetch_responses }
  ensure
    barrier.stop
  end

  private

  def send_responses
    last_task = nil
    loop do
      response = @response_queue.dequeue
      break if response == :exit_signal

      last_task&.wait
      last_task = async { send_response(stream, response) }
    rescue StandardError => e
      @logger.error("Failed to process response: #{e}")
      send_error(e.status_code)
    ensure
      last_task&.wait
    end
  end

  def fetch_responses
    barrier     = Async::Barrier.new
    semaphore   = Async::Semaphore.new(@config[:limits][:max_concurrent_requests_per_client])
    priority    = 0

    while request = @request_queue.dequeue
      priority++
  
      semaphore.acquire

      barrier.async do
        @request_validator.validate_request(request)
        fetch_response(request)
        @response_queue.enqueue(priority, response)
      end

      semaphore.release
      
    rescue StandardError => e
      @logger.error("Failed to process request: #{e}")
      send_error(e.status_code)
    end

    barrier.wait
    @response_queue.enqueue(priority, :exit_signal)
  ensure
    barrier.stop
  end
  
  def fetch_response(request)
    return @response_queue.enqueue(priority, Response.new(200, {"Content-Length" => "16"}, "pong...fumasters")) if request.path == "/ping"

    grpc_response = @grpc_client.send(#TODO mapping)
    #TODO parse da grpc a http
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