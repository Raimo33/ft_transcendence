#!/usr/bin/env ruby

require 'eventmachine'
require_relative 'lib/grpc_server'
require_relative 'lib/server'

if $PROGRAM_NAME == __FILE__
  EM.run do
    game_server = Server.new
    grpc_server = GrpcServer.new

    EM.defer { game_server.run }
    EM.defer { grpc_server.run }
  end
rescue StandardError => e
  puts "Uknown error: #{e}"
  exit 1
end