# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:22 by craimond          #+#    #+#              #
#    Updated: 2024/10/20 08:33:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'socket'
require 'json'
require 'deque'
require_relative 'endpoint_tree'
require_relative 'jwt_validator'
require_relative 'grpc_client'
require_relative 'response_formatter'
require_relative 'helpers'
require_relative 'thread_pool'

class Server
  def initialize
    @endpoint_tree = EndpointTreeNode.new('v1')
    @endpoint_tree.parse_swagger_file('app/config/API_swagger.yaml')
    @jwt_validator = JwtValidator.new
    @server = TCPServer.new(ENV['API_GATEWAY_HOST'], ENV['API_GATEWAY_PORT'])
    @clients = []
    @response_queue = Deque.new
    @thread_pool = ThreadPool.new(ENV['THREAD_POOL_SIZE'].to_i)
  end

  def run
    loop do
      readable, _, error = IO.select([@server] + @clients, nil, @clients)

      readable.each do |socket|
        if socket == @server
          handle_new_client
        else
          handle_existing_client(socket)
        end
      end

      error.each do |socket|
        handle_socket_error(socket)
      end

      process_response_queue
    end
  end

  private

  def handle_new_client
    client = @server.accept_nonblock
    @clients << client
  end

  def handle_existing_client(socket)
    request_line = socket.gets
    if request_line
      method, path, _ = request_line.split
      endpoint_node = @endpoint_tree.find_path(path)

      method = method.to_sym
      unless endpoint_node && HttpMethod::VALID_HTTP_METHODS.include?(method)
        return_error(socket, 404, 'Invalid path or method')
        @clients.delete(socket)
        return
      end

      api_method = endpoint_node.endpoint_data[method]
      unless api_method
        return_error(socket, 405, 'Method not allowed')
        @clients.delete(socket)
        return
      end

      if handle_client_request(socket, endpoint_node, api_method)
        @clients.delete(socket)
        socket.close
      end
    else
      @clients.delete(socket)
      socket.close
    end
  end

  def handle_client_request(socket, endpoint_node, api_method)
    if api_method.auth_level != AuthLevel::NONE
      headers = extract_headers(socket)
      unless check_auth_header(headers['authorization'], @jwt_validator, api_method.auth_level)
        return_error(socket, 401, 'Invalid or missing JWT token')
        return false
      end
    end

    begin
      if api_method.is_async
        socket.puts "HTTP/1.1 202 Accepted\r\nContent-Type: application/json\r\n\r\n"
        @thread_pool.schedule do
          response = # Placeholder for gRPC service call
          if socket_ready_for_write?(socket)
            @response_queue.push_front({ socket: socket, response: response })
          else
            @response_queue.push_back({ socket: socket, response: response })
          end
        end
      else
        response = # Placeholder for gRPC service call
        socket.puts "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n"
        socket.puts response.to_json
      end
    rescue StandardError => e
      return_error(socket, 500, e.message)
    end

    true
  end

  def handle_socket_error(socket)
    STDERR.puts "Socket error occurred: #{socket}"
    @clients.delete(socket)
    socket.close
  end

  def process_response_queue
    until @response_queue.empty?
      item = @response_queue.pop_front
      socket = item[:socket]
      response = item[:response]

      if socket.closed?
        next
      end

      @thread_pool.schedule do
        begin
          socket.puts "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n"
          socket.puts response.to_json
          @clients.delete(socket)
          socket.close
        rescue StandardError => e
          STDERR.puts "Error sending response: #{e.message}"
          @clients.delete(socket)
          socket.close
        end
      end
    end
  end

  def socket_ready_for_write?(socket)
    _, writeable, _ = IO.select(nil, [socket], nil, 0)
    !writeable.empty?
  end
end
