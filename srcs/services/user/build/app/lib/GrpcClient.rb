# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcClient.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/08 23:00:33 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../proto/query_service_pb'
require_relative '../proto/tournament_service_pb'
require_relative './modules/ConfigLoader'
require_relative './modules/Logger'

class GrpcClient
  include ConfigLoader
  include Logger

  def initialize
    @config = ConfigLoader.config
    @logger = Logger.logger
    @logger.info('Initializing grpc client')

    options = {
      'grpc.compression_algorithm' => 'gzip'
    }

    query_credentials  = load_credentials(@config[:query_cert])

    user_channel  = create_channel(@config[:query_addr], query_credentials)

    @stubs = {
      query: QueryService::Stub.new(user_channel),
    }.freeze

    @request_mapping = {
      #TODO: Add request mappings for QueryService
    }.freeze

  rescue StandardError => e
    raise "Failed to initialize grpc client: #{e}"
  ensure
    close
  end

  def call(grpc_request)
    mapping = @request_mapping[grpc_request.class]
    raise "No mapping found for request: #{grpc_request.class}" unless mapping

    stub = mapping[:stub]
    method = mapping[:method]
    @logger.debug("Calling grpc method #{method} with request: #{grpc_request} on stub: #{stub}")
    response = stub.send(method, grpc_request)
    @logger.debug("Received response: #{response}")

  rescue StandardError => e
    raise "Failed to call grpc method #{method}: #{e}"
  end

  def close
    @logger.info('Closing grpc client')
    @stubs.each do |channel|
      channel&.close if defined?(channel) && channel.respond_to?(:close)
    end
  end

  private

  def load_credentials(cert_file)
    raise "Certificate file not found: #{cert_file}" unless File.exist?(cert_file)
    @logger.debug("Loading credentials from #{cert_file}")
    GRPC::Core::ChannelCredentials.new(File.read(cert_file))
  rescue StandardError => e
    raise "Failed to load credentials from #{cert_file}: #{e}"
  end

  def create_channel(addr, credentials)
    @logger.debug("Creating channel to #{addr}")
    GRPC::Core::Channel.new(addr, nil, credentials)
  rescue StandardError => e
    raise "Failed to create channel to #{addr}: #{e}"
  end

end
