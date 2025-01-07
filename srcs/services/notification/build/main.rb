#!/usr/bin/env ruby

require 'falcon'
require 'grpc'
require_relative 'srcs/request_handler'
require_relative 'srcs/shared/config_handler'
require_relative 'srcs/shared/logger'
require_relative 'srcs/middlewares/logger_interceptor'
require_relative 'srcs/middlewares/exception_interceptor'
require_relative 'srcs/protos/notification_app_services_pb'
require_relative 'srcs/handlers/notification_app_service_handler'

config = ConfigHandler.instance.config

def start_falcon_server
  settings = config.dig(:server)

  falcon_config = Falcon::Server::Configuration.new do |c|
    c.bind = "http://#{settings.fetch(:bind)}:#{settings.fetch(:port)}"
    c.protocol = Falcon::HTTP1
    c.reuse_port = true
    c.quiet = true
    c.timeout = 0
    c.buffer_size = 4096
    c.proxy_protocol = false
  end

  app, options = Rack::Builder.parse_file('config/config.ru')
  server = Falcon::Server.new(app, falcon_config)

  server
end

def start_grpc_server
  settings = config.dig(:grpc, :server)

  server = GRPC::RpcServer.new(
    server_host: settings.fetch(:host)
    server_port: settings.fetch(:port)
    pool_size: settings.fetch(:pool_size)
    interceptors:  [
      LoggerInterceptor.new,
      ExceptionInterceptor.new,
    ]
    logger: CustomLogger.instance.logger
  )
  server.handle(NotificationApp::Service, NotificationAppServiceHandler.new)

  server
end

if $PROGRAM_NAME == __FILE__
  begin
    falcon_server = start_falcon_server
    grpc_server   = start_grpc_server

    falcon_thread = Thread.new { falcon_server.run }
    grpc_thread   = Thread.new { grpc_server.run_till_terminated }

    Signal.trap("INT") {do
      falcon_server.stop
      grpc_server.stop
    end}
    Signal.trap("TERM") do
      falcon_server.stop
      grpc_server.stop
    end

    falcon_thread.join
    grpc_thread.join
  rescue => e
    puts "Error: #{e}"
    exit 1
  end
end