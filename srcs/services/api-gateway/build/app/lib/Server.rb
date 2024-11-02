# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/25 18:47:57 by craimond          #+#    #+#              #
#    Updated: 2024/11/02 18:41:41 by craimond         ###   ########.fr        #
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
require_relative 'GrpcClient'
require_relative 'ConfigLoader'
require_relative 'Logger'

class Server
  include ConfigLoader
  include Logger

  def initialize(grpc_client)
    @config = Config.config
    @logger = Logger.logger
    @logger.info('Initializing server...')

    @grpc_client = grpc_client
    @endpoint_tree = EndpointTree.new('')
    @swagger_parser = SwaggerParser.new('/app/config/openapi.yaml')
    @jwt_validator = JWTValidator.new
    @clients = Async::Queue.new

    @swagger_parser.fill_endpoint_tree(@endpoint_tree)
    @logger.info('Server initialized')
  rescue StandardError => e
    raise "Error initializing server: #{e}"
  end

  def run
    Sync do
      @logger.info('Starting server...')
      endpoint = Async::IO::Endpoint.tcp(@config[:bind_address], @config[:port])
      @logger.debug("Server listening on #{@config[:bind_address]}:#{@config[:port]}")
      semaphore = Async::Semaphore.new(@config[:max_connections])

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
  rescue StandardError => e
    @logger.error("Unable to handle connection: #{socket}: #{e}")
    @logger.debug(e.backtrace.join("\n"))
  end

  def process_requests
    Async do |task|
      loop do
        begin
          client_handler = @clients.dequeue
          task.async { client_handler.process_requests }
        rescue StandardError => e
          client_info = client_handler&.socket || 'unknown'
          @logger.error("Unable to process client: #{client_info}: #{e}")
          @logger.debug(e.backtrace.join("\n"))
        end
      end
    end
  end