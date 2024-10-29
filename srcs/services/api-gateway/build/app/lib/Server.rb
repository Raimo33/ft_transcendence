# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/25 18:47:57 by craimond          #+#    #+#              #
#    Updated: 2024/10/29 15:12:52 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'set'
require 'async'
require 'async/io'
require 'async/queue'
require 'async/io/tcp_socket'
require_relative 'EndpointTree'
require_relative 'ClientHandler'
require_relative 'JwtValidator'
require_relative 'ServerExceptions'
require_relative 'SwaggerParser'
require_relative 'structs'

class Server

  def initialize(grpc_client)
    @grpc_client = grpc_client
    @endpoint_tree = EndpointTree.new('v1')
    @swagger_parser = SwaggerParser.new('/app/config/openapi.yaml')
    @jwt_validator = JWTValidator.new
    @mapper = Mapper.new
    @clients = Async::Queue.new

    @swagger_parser.fill_endpoint_tree(@endpoint_tree)
  end

  def run
    Sync do
      endpoint = Async::IO::Endpoint.tcp($BIND_ADDRESS, $PORT)
      semaphore = Async::Semaphore.new($MAX_CONNECTIONS)

      Thread.new { process_requests }

      loop do
        endpoint.accept do |socket|
          semaphore.async { handle_connection(socket) }
      end
    end
  end

  private

  def handle_connection(socket)
    client_handler = ClientHandler.new(socket, @endpoint_tree, @grpc_client, @jwt_validator, @mapper)
    @clients.enqueue(client_handler)
    client_handler.read_requests
  rescue => e
    #TODO log error (Unable to handle connection: <socket>. Reason: <error>)
  end

  def process_requests
    Async do |task|
      loop do
        client_handler = @clients.dequeue
        task.async { client_handler.process_requests }
      rescue => e
        #TODO log error (Unable to process client: <socket> requests. Reason: <error>)
      end
    end
  end