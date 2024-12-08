#!/usr/bin/env ruby

require_relative 'lib/grpc_server'


if $PROGRAM_NAME == __FILE__
  server = GrpcServer.new

  server.run
rescue StandardError => e
  puts "Uknown error: #{e}"
  exit 1
end