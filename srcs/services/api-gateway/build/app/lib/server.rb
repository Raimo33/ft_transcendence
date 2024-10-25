# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/25 18:47:57 by craimond          #+#    #+#              #
#    Updated: 2024/10/25 20:49:38 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'set'
require 'async'
require 'async/io'
require 'async/queue'
require 'async/io/tcp_socket'

class Server
  HTTP_METHODS_REQUIRING_BODY = %w[POST PUT PATCH].to_set

  def initialize(grpc_client)
    @grpc_client = grpc_client
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
        client, request = @request_queue.dequeue
        semaphore.async { _handle_request(client, request) }
      end
    end
  end

  def _handle_client(client)
    buffer = String.new
    stream = Async::IO::Stream.new(client)

    while chunk = stream.read(4096)
      buffer << chunk

      while request = _extract_request(buffer)
        @request_queue.enqueue([client, request])
      end
    end
  end

  def _extract_request(buffer)

    header_end = buffer.index("\r\n\r\n")
    return nil unless header_end
    
    headers_part = buffer.slice!(0, header_end)
    body_start_index = header_end + 4
  
    headers_lines = headers_part.split("\r\n")
    request_line = headers_lines.shift
    headers = {}
  
    headers_lines.each do |line|
      key, value = line.split(": ", 2)
      headers[key.downcase] = value
    end

    content_length = headers["content-length"]&.to_i
    method = request_line.split(" ")[0].upcase
  
    if HTTP_METHODS_REQUIRING_BODY.include?(method)
      return send_error(411) unless content_length
      return send_error(413) if content_length > $MAX_BODY_SIZE
    end
  
    total_request_size = body_start_index + content_length
    return nil if buffer.size < total_request_size

    body = buffer.slice!(body_start_index, content_length) if content_length > 0
    { request_line: request_line, headers: headers, body: body }
  end

  def _handle_request(client, request)
    #TODO: Implement this method
  