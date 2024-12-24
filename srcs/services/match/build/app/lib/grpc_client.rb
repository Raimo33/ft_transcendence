# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_client.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/12/24 18:16:30 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'singleton'
require_relative 'ConfigHandler'
require_relative '../protos/matchmaking_user_services_pb'
require_relative '../protos/game_state_user_services_pb'
require_relative '../protos/notification_user_services_pb'
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
      matchmaking: create_channel(@config.dig(:grpc, :client, :addresses, :matchmaking)),
      game_state: create_channel(@config.dig(:grpc, :client, :addresses, :game_state)),
      notification: create_channel(@config.dig(:grpc, :client, :addresses, :notification))
    }

    @stubs = {
      matchmaking: Matchmaking::Stub.new(@channels[:matchmaking], interceptors: interceptors),
      game_state: GameState::Stub.new(@channels[:game_state], interceptors: interceptors),
      notification: Notification::Stub.new(@channels[:notification], interceptors: interceptors)
    }
  ensure
    stop
  end

  def stop
    @channels.each_value(&:close)
  end

  def add_matchmaking_user()

  def remove_matchmaking_user()

  def add_match_invitation()
  
  def remove_match_invitation()

  def accept_match_invitation()

  def setup_game_state()

  def close_game_state()

  def notify_match_invitation(from_user_id:, to_user_id:, metadata = {})
    request = NotificationUser::NotifyMatchInvitationRequest(
      from_user_id: from,
      to_user_id:   to
    )

    @stubs[:notification].notify_match_invitation(request, metadata: metadata)
  end


  private

  def create_channel(addr)
    GRPC::Core::Channel.new(addr, @connection_options, credentials: :this_channel_is_insecure)
  end

end
