#!/usr/bin/env ruby

require 'falcon'
require_relative 'srcs/server'

if $PROGRAM_NAME == __FILE__
  begin

    config = Falcon::Server::Configuration.new do |config|
      config.bind = 'http://0.0.0.0:3000'
      config.protocol = Falcon::HTTP1
      config.reuse_port = true
      config.quiet = true
    end

    app, options = Rack::Builder.parse_file('config/config.ru')
    
    server = Falcon::Server.new(app, config)
    
    Signal.trap('INT') { server.stop }
    Signal.trap('TERM') { server.stop }
    
    server.run
  rescue StandardError => e
    puts "Error: #{e}"
    exit 1
  end
end