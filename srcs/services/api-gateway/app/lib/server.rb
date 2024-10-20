# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:22 by craimond          #+#    #+#              #
#    Updated: 2024/10/20 20:31:57 by craimond         ###   ########.fr        #
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
    @server = TCPServer.new($BIND_ADDRESS, $BIND_PORT)
    @clients = []
    @callbacks_queue = Deque.new
    @thread_pool = ThreadPool.new($THREAD_POOL_SIZE)
  end

  def run
    loop do
      readable, _, error = IO.select([@server] + @clients, nil, @clients)

      readable.each do |socket|
        if socket == @server
          _handle_new_client
        else
          _handle_existing_client(socket)
        end
      end

      error.each do |socket|
        _handle_socket_error(socket)
      end

      _route_responses
    end
  end

  def stop
    @clients.each do |client|
      client.close
    end
    @server.close
    @thread_pool.shutdown
  end

  private

  def _handle_new_client
    client = @server.accept_nonblock
    @clients << client
  end

  def _handle_existing_client(socket)
    request_line = socket.gets
    if request_line
      method, path, _ = request_line.split
      endpoint_node = @endpoint_tree.find_path(path) #TODO use a trie instead of tree?

      api_method = endpoint_node.endpoint_data[method]
      unless api_method
        return_error(socket, 405)
        @clients.delete(socket)
        return
      end

      _handle_client_request(socket, api_method)
    end
  end

  def _handle_client_request(socket, api_method)
    headers = extract_headers(socket)
    return unless _check_auth(socket, api_method, headers)

    body = extract_body(socket, headers)
    #TODO trasformazione da body a request, estrazione del callback url

    begin
      if api_method.is_async
        #TODO check del callback url
        socket.puts "HTTP/1.1 202 Accepted\r\nContent-Type: application/json\r\n\r\n"
        @thread_pool.schedule do
          response = api_method.service.send(api_method.method, request)
          queue_method = socket_ready_for_write?(socket) ? :push_front : :push_back
          @response_queue.send(queue_method, { socket: socket, response: response })
        end
      else
        response = api_method.service.send(api_method.method, request)
        return_response(socket, response)
      end
    rescue StandardError => e
      return_error(socket, 500)
    end

    true
  end

  def _handle_socket_error(socket)
    STDERR.puts "Socket error occurred: #{socket}"
    @clients.delete(socket)
    socket.close
  end

  def _process_callbacks
    until @callbacks_queue.empty?
      item = @callbacks_queue.pop_front
      socket = item[:socket]
      response = item[:response]

      if socket.closed?
        next
      end

      @thread_pool.schedule do
        begin
          return_response_callback(socket, response)
        rescue StandardError => e
          STDERR.puts "Error sending response: #{e.message}"
        @clients.delete(socket)
        socket.close
        end
      end
    end
  end

  def _check_auth(socket, api_method, headers)
    if api_method.auth_level != AuthLevel::NONE
      unless check_auth_header(headers['authorization'], @jwt_validator, api_method.auth_level)
        return_error(socket, 401, 'Invalid or missing JWT token')
        return false
      end
    end

  def _socket_ready_for_write?(socket)
    _, writeable, _ = IO.select(nil, [socket], nil, 0)
    !writeable.empty?
  end
end
