#!/usr/bin/env ruby

require_relative 'lib/grpc_server'

if $PROGRAM_NAME == __FILE__

  registry = ServiceRegistry.instance
  registry.register(UserAPIGatewayService, UserAPIGatewayServiceHandler)
  #TODO add more services here

  server = GrpcServer.new

  begin
    puts "Starting gRPC server on"
    server.run
  rescue StandardError => e
    puts "Failed to start server: #{e.message}"
    exit 1
  end
end