#!/usr/bin/env ruby

require 'eventmachine'
require_relative 'srcs/grpc_server'
require_relative 'srcs/server'

if $PROGRAM_NAME == __FILE__
  EM.run do
    server = Server.instance
    grpc_server = GrpcServer.new

    EM.defer { server.run }
    EM.defer { grpc_server.run }
  end
rescue StandardError => e
  puts "Uknown error: #{e}"
  exit 1
end