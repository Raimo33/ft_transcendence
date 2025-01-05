# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_client.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:37:07 by craimond          #+#    #+#              #
#    Updated: 2025/01/05 17:55:02 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'yaml'
require 'singleton'
require_relative 'ConfigHandler'
require_relative 'protos/notification_app_services_pb'
require_relative 'protos/match_state_app_services_pb'
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
      match_state: create_channel(@config.dig(:grpc, :client, :addresses, :match_state)),
      notification: create_channel(@config.dig(:grpc, :client, :addresses, :notification))
    }

    @stubs = {
      match_state: MatchStateApp::Stub.new(channels[:match_state], interceptors: interceptors),
      notification: NotificationApp::Stub.new(channels[:notification], interceptors: interceptors)
    }
  end

  def setup_match_state(match_id, user_id1, user_id2)
    request = MatchStateApp::SetupMatchStateRequest.new(match_id, user_id1, user_id2)
    @stubs[:match_state].setup_match_state(request)
  end

  def close_match_state(match_id)
    request = MatchStateApp::MatchId.new(match_id)
    @stubs[:match_state].close_match_state(request)
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

