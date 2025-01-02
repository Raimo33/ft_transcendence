# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_server.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 19:30:45 by craimond          #+#    #+#              #
#    Updated: 2025/01/02 13:24:44 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative 'config_handler'
require_relative '../protos/notification_user_service_pb'
require_relative '../protos/notification_match_service_pb'
require_relative 'handlers/notification_match_service_handler'
require_relative 'handlers/notification_user_service_handler'
require_relative 'interceptors/logger_interceptor'
require_relative 'interceptors/exception_interceptor'
require_relative 'interceptors/request_context_interceptor'

class GrpcServer

  def initialize
    @config = ConfigHandler.instance.config

    @server = GRPC::RpcServer.new(
      server_host:   @config.dig(:grpc, :server, :host),
      server_port:   @config.dig(:grpc, :server, :port),
      pool_size:     @config.dig(:grpc, :server, :pool_size),
      interceptors:  [
        LoggerInterceptor.new,
        ExceptionInterceptor.new,
        RequestContextInterceptor.new
      ]
    )

    @services = {
      NotificationUserService => NotificationUserServiceHandler.new,
      NotificationMatchService => NotificationMatchServiceHandler.new
    }

    setup_handlers
  end

  def run
    @server.run_till_terminated_or_interrupted([1, "int", "TERM"])
  end

  private

  def setup_handlers
    @services.each do |service, handler|
      @server.handle(service, handler)
    end
  end

end
