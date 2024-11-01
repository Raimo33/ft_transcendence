# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/25 18:47:57 by craimond          #+#    #+#              #
#    Updated: 2024/11/01 19:10:55 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require 'async/io'
require 'async/queue'
require 'async/semaphore'
require_relative 'EndpointTree'
require_relative 'SwaggerParser'
require_relative 'JWTValidator'
require_relative 'ClientHandler'
require_relative 'Logger'

class Server

  def initialize(grpc_client)
    @logger = Logger.logger
    @logger.info('Initializing server...')
    @grpc_client = grpc_client
    @endpoint_tree = EndpointTree.new('v1')
    @swagger_parser = SwaggerParser.new('/app/config/openapi.yaml')
    @jwt_validator = JWTValidator.new
    @clients = Async::Queue.new

    @swagger_parser.fill_endpoint_tree(@endpoint_tree)
    @logger.info('Server initialized')
  rescue => e
    @logger.fatal("Error initializing server: #{e}")
    raise
  end

  def run
    Sync do
      @logger.info('Starting server...')
      endpoint = Async::IO::Endpoint.tcp($BIND_ADDRESS, $PORT)
      @logger.debug("Server listening on #{$BIND_ADDRESS}:#{$PORT}")
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
    @logger.debug("Handling connection: #{socket}")
    client_handler = ClientHandler.new(socket, @endpoint_tree, @grpc_client, @jwt_validator)
    @clients.enqueue(client_handler)
    client_handler.read_requests
  rescue => e
    @logger.error("Unable to handle connection: #{socket}. Reason: #{e}")
  end

  def process_requests
    Async do |task|
      loop do
        begin
          client_handler = @clients.dequeue
          task.async { client_handler.process_requests }
        rescue => e
          client_info = client_handler&.socket || 'unknown'
          @logger.error("Unable to process client: #{client_info} requests. Reason: #{e}")
        end
      end
    end
  end