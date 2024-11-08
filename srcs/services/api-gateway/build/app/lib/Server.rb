# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/25 18:47:57 by craimond          #+#    #+#              #
#    Updated: 2024/11/08 23:00:19 by craimond         ###   ########.fr        #
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
require_relative './modules/ConfigLoader'
require_relative './modules/Logger'

class Server
  include ConfigLoader
  include Logger

  def initialize
    @config = ConfigLoader.config
    @logger = Logger.logger

    @logger.info('Initializing server...')
    @grpc_client = GrpcClient.new
    @endpoint_tree = EndpointTree.new('')
    @swagger_parser = SwaggerParser.new('/app/config/openapi.yaml')
    @rate_limiter = RateLimiter.new
    @jwt_validator = JWTValidator.new
    @clients = Async::Queue.new

    ssl_context = load_ssl_context(@config[:api_gateway_key], @config[:api_gateway_cert])

    @swagger_parser.fill_endpoint_tree(@endpoint_tree)
    @swagger_parser.fill_rate_limiter(@rate_limiter)

  rescue StandardError => e
    raise "Failed to initialize server: #{e}"
  ensure
    @grpc_client&.close if defined?(@grpc_client)
  end

  def run
    Sync do
      @logger.info('Starting server...')
      endpoint = Async::IO::Endpoint.tcp(@config[:bind_address], @config[:port])
      ssl_endpoint = Async::IO::Endpoint.ssl(endpoint, ssl_context)
      @logger.debug("Server listening on #{@config[:bind_address]}:#{@config[:port]}")
      semaphore = Async::Semaphore.new(@config[:max_connections])

      Thread.new { process_requests }

      loop do
        ssl_endpoint.accept do |socket|
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
        end
      end
    end
  end

  def load_ssl_context(ssl_key, ssl_cert)
    @logger.info("Loading SSL context...")
    ssl_context = OpenSSL::SSL::SSLContext.new
    ssl_context.cert = OpenSSL::X509::Certificate.new(File.open(ssl_cert))
    ssl_context.key = OpenSSL::PKey::RSA.new(File.open(ssl_key))
    ssl_context
  rescue StandardError => e
    raise "Failed to load SSL context: #{e}"
  end

end
