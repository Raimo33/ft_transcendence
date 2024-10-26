# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/25 18:47:57 by craimond          #+#    #+#              #
#    Updated: 2024/10/26 23:11:56 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'set'
require 'async'
require 'async/io'
require 'async/queue'
require 'async/io/tcp_socket'
require_relative 'endpoint_tree'
require_relative 'client_handler'
require_relative 'jwt_validator'
require_relative 'server_exceptions'

class Server
  def initialize(grpc_client)
    @grpc_client = grpc_client
    @endpoint_tree = EndpointTreeNode.new('v1')
    @endpoint_tree.parse_swagger_file('/app/config/swagger.yaml')
    @jwt_validator = JWTValidator.new
    @clients = Async::Queue.new
  end

  def run
    Sync do
      endpoint = Async::IO::Endpoint.tcp($BIND_ADDRESS, $PORT)
      semaphore = Async::Semaphore.new($MAX_CONNECTIONS)

      Thread.new { _process_requests }

      loop do
        endpoint.accept do |socket|
          semaphore.async { _handle_connection(socket) }
      end
    end
  end

  private

  def _handle_connection(socket)
    client_handler = ClientHandler.new(socket, @endpoint_tree, @grpc_client, @jwt_validator)
    @clients.enqueue(client_handler)
    client_handler.read_requests
  rescue => e
    #TODO log error (Unable to handle connection: <socket>. Reason: <error>)
  end

  def _process_requests
    Async do |task|
      loop do
        client_handler = @clients.dequeue
        task.async { client_handler.process_requests }
      rescue => e
        #TODO log error (Unable to process client: <socket> requests. Reason: <error>)
      end
    end
  end