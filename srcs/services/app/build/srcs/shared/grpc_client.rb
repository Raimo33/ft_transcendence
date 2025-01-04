# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_client.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:37:07 by craimond          #+#    #+#              #
#    Updated: 2025/01/04 00:30:07 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'yaml'
require 'singleton'
require_relative 'ConfigHandler'
require_relative 'protos/notification_app_services_pb'
require_relative 'protos/game_state_app_services_pb'
require_relative '../middlewares/client/logger_interceptor'
require_relative '../middlewares/client/exceptions_interceptor'
require_relative '../middlewares/client/metadata_interceptor'

class GrpcClient
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config

    @connection_options = {
      "grpc.compression_algorithm" => "gzip"
    }

    interceptors = [
      LoggerInterceptor.new
      ExceptionsInterceptor.new
      MetadataInterceptor.new
    ]

    channels = {
      game_state: create_channel(@config.dig(:grpc, :client, :addresses, :game_state)),
      notification: create_channel(@config.dig(:grpc, :client, :addresses, :notification))
    }

    @stubs = {
      game_state: GameStateApp::Stub.new(channels[:game_state], interceptors: interceptors),
      notification: NotificationApp::Stub.new(channels[:notification], interceptors: interceptors)
    }
  end

  def stop
    @channels.each_value(&:close)
  end

  def setup_game_state(match_id, user_id1, user_id2)
    request = GameStateApp::SetupGameStateRequest.new(match_id, user_id1, user_id2)
    @stubs[:game_state].setup_game_state(request)
  end

  def close_game_state(match_id)
    request = GameStateApp::MatchId.new(match_id)
    @stubs[:game_state].close_game_state(request)
  end

  def notify_friend_request(sender_id, recipient_id)
    request = NotificationApp::FriendRequest.new(sender_id, recipient_id)
    @stubs[:notification].notify_friend_request(request)
  end

  def notify_friend_request_accepted(sender_id, recipient_id)
    request = NotificationApp::FriendRequest.new(sender_id, recipient_id)
    @stubs[:notification].notify_friend_request_accepted(request)
  end

  def notify_match_found(match_id, user_id_1, user_id_2)
    request = NotificationApp::MatchFound.new(match_id, user_id_1, user_id_2)
    @stubs[:notification].notify_match_found(request)
  end

  private

  def create_channel(addr)
    GRPC::Core::Channel.new(addr, @connection_options, credentials: :this_channel_is_insecure)
  end
  
end

