#!/usr/bin/env ruby

require 'falcon'
require_relative 'srcs/server'
require_relative 'srcs/shared/config_handler'

config = ConfigHandler.instance.config

def start_falcon_server
  settings = config.dig(:server)

  falcon_config = Falcon::Server::Configuration.new do |c|
    config.bind = "http://#{settings.fetch(:bind)}:#{settings.fetch(:port)}"
    config.protocol = Falcon::HTTP1
    config.reuse_port = true
    config.quiet = true
  end

  app, options = Rack::Builder.parse_file('config/config.ru')
  server = Falcon::Server.new(app, falcon_config)

  server
end

if $PROGRAM_NAME == __FILE__
  begin
    falcon_server = start_falcon_server

    falcon_thread = Thread.new { falcon_server.run }

    Signal.trap("INT") { falcon_server.stop }
    Signal.trap("TERM") { falcon_server.stop }

    falcon_thread.join
  rescue StandardError => e
    puts "Error: #{e.message}"
    exit 1
  end
end