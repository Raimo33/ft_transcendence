# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_client.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/12/29 00:51:53 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'singleton'
require_relative 'ConfigHandler'
require_relative '../protos/game_state_match_services_pb'
require_relative '../protos/game_state_auth_services_pb'
require_relative 'interceptors/metadata_interceptor'
require_relative 'interceptors/logger_interceptor'

class GrpcClient
  include Singleton
  
  def initialize
    @config = ConfigHandler.instance.config

    @connection_options = {
      "grpc.compression_algorithm" => "gzip"
    }

    interceptors = [
      MetadataInterceptor.new,
      LoggerInterceptor.new
    ]

    @channels = {
      match: create_channel(@config.dig(:grpc, :client, :addresses, :match)),
      auth: create_channel(@config.dig(:grpc, :client, :addresses, :auth)),
    }

    @stubs = {
      match: GameStateMatch::Stub.new(@channels[:match], interceptors: interceptors),
      auth: GameStateAuth::Stub.new(@channels[:auth], interceptors: interceptors),
    }
  ensure
    stop
  end

  def validate_session_token(token, metadata = {})
    request = Common::JWT.new(jwt: token)
    @stubs[:auth].validate_session_token(request, metadata: metadata)
  end

  def save_match(match_id, winner_id, ended_at, metadata = {})
    request = GameStateMatch::MatchResult.new(
      match_id: match_id,
      winner_id: winner_id,
      ended_at: Google::Protobuf::Timestamp.new(seconds: ended_at)
    )

    @stubs[:match].save_match(request, metadata: metadata)
  end

  private

  def create_channel(addr)
    GRPC::Core::Channel.new(addr, @connection_options, credentials: :this_channel_is_insecure)
  end

end
