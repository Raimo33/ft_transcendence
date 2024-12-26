# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_client.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/12/26 17:18:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'singleton'
require_relative 'ConfigHandler'
require_relative #TODO protos
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
      match
    }

    @stubs = {
      match
    }
  ensure
    stop
  end

  def stop
    @channels.each_value(&:close)
  end

  def match_found(user_id_1:, user_id_2:, metadata = {})
    request = MatchmakingMatch::MatchedPlayers.new(user_id_1: user_id_1, user_id_2: user_id_2)
    @stubs[:match].match_found(request, metadata: metadata)
  end

  private

  def create_channel(addr)
    GRPC::Core::Channel.new(addr, @connection_options, credentials: :this_channel_is_insecure)
  end

end
