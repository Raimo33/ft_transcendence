# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcClient.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/02 15:38:12 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../proto/users_services_pb'
require_relative '../proto/match_services_pb'
require_relative '../proto/tournament_services_pb'
require_relative 'Logger'

class GrpcClient

  def initialize
    @logger = Logger.logger
    @logger.info('Initializing grpc client')

    options = {
      'grpc.compression_algorithm' => 'gzip'
    }

    user_server_credentials        = load_credentials($USER_SERVER_CERT)
    match_server_credentials       = load_credentials($MATCH_SERVER_CERT)
    tournament_server_credentials  = load_credentials($TOURNAMENT_SERVER_CERT)

    user_channel        = create_channel($USER_GRPC_SERVER_ADDR, user_server_credentials)
    match_channel       = create_channel($MATCH_GRPC_SERVER_ADDR, match_server_credentials)
    tournament_channel  = create_channel($TOURNAMENT_GRPC_SERVER_ADDR, tournament_server_credentials)

    @user_stub          = Users::Stub.new(user_channel)
    @match_stub         = Match::Stub.new(match_channel)
    @tournament_stub    = Tournament::Stub.new(tournament_channel)

  rescue StandardError => e
    raise "Error initializing grpc client: #{e}"
  end

  def call(grpc_request)
    @logger.debug("Calling grpc method #{grpc_request.method}")
    #TODO deduce stub and call the method based on grpc_request object
  end

  private

  def load_credentials(cert_file)
    raise "Certificate file not found: #{cert_file}" unless File.exist?(cert_file)
    @logger.debug("Loading credentials from #{cert_file}")
    GRPC::Core::ChannelCredentials.new(File.read(cert_file))
  rescue StandardError => e
    raise "Failed to load credentials from #{cert_file}: #{e.message}"
  end

  def create_channel(addr, credentials)
    @logger.debug("Creating channel to #{addr}")
    GRPC::Core::Channel.new(addr, nil, credentials)
  rescue StandardError => e
    raise "Failed to create channel to #{addr}: #{e.message}"
  end

end
