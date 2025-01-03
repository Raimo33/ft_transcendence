# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_client.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:37:07 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 12:06:03 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'yaml'
require 'singleton'
require_relative 'ConfigHandler'
require_relative 'protos/app_notification_services_pb'
require_relative 'protos/app_game_state_services_pb'
require_relative 'middlewares/client/logger_interceptor'

class GrpcClient
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config

    @connection_options = {
      "grpc.compression_algorithm" => "gzip"
    }

    interceptors = [LoggerInterceptor.new]

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

  #TODO add methods to call the gRPC services

  private

  def create_channel(addr)
    GRPC::Core::Channel.new(addr, @connection_options, credentials: :this_channel_is_insecure)
  end
  
end

