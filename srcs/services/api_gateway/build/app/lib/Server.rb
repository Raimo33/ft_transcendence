# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/25 18:47:57 by craimond          #+#    #+#              #
#    Updated: 2024/11/15 22:02:46 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "async"
require "async/io"
require "async/queue"
require "async/semaphore"
require_relative "EndpointTree"
require_relative "SwaggerParser"
require_relative "JWTValidator"
require_relative "ClientHandler"
require_relative "GrpcClient"
require_relative "ConfigLoader"
require_relative "ConfigurableLogger"

class Server

  def initialize
    Signal.trap("SIGTERM") { stop }

    @config = ConfigLoader.config
    @logger = ConfigurableLogger.instance.logger

    @logger.info("Initializing server...")
    @grpc_client = GrpcClient.new
    @endpoint_tree = EndpointTree.new('')
    @swagger_parser = SwaggerParser.new("/app/config/openapi.yaml")
    @jwt_validator = JWTValidator.new
    @clients = Async::Queue.new

    @swagger_parser.fill_endpoint_tree(@endpoint_tree)
  rescue StandardError => e
    raise "Failed to initialize server: #{e}"
  ensure
    @grpc_client&.close if defined?(@grpc_client)
  end

  def run
    Sync do
      @logger.info("Starting server...")
      bind_address, port = @config[:bind].split(":")
      endpoint = Async::IO::Endpoint.tcp(bind_address, port)
      @logger.debug("Server listening on #{bind_address}:#{port}")
      semaphore = Async::Semaphore.new(@config[:limits][:max_connections])

      Thread.new { process_requests }

      loop do
        endpoint.accept do |socket|
          semaphore.async { handle_connection(socket) }
      end
    end
  end

  def stop
    @logger.info("Stopping server...")
    @grpc_client.close
  end

  private

  def handle_connection(socket)
    @logger.debug("Handling connection: #{socket}")
    client_handler = ClientHandler.new(socket, @endpoint_tree, @grpc_client, @jwt_validator)
    @clients.enqueue(client_handler)
    client_handler.read_requests
  rescue StandardError => e
    @logger.error("Unable to handle connection: #{socket}: #{e}")
  end

  def process_requests
    Async do |task|
      loop do
        begin
          client_handler = @clients.dequeue
          task.async { client_handler.process_requests }
        rescue StandardError => e
          client_info = client_handler&.socket || "unknown"
          @logger.error("Unable to process client: #{client_info}: #{e}")
        end
      end
    end
  end

end
