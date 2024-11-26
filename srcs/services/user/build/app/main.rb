#!/usr/bin/env ruby

require_relative 'lib/grpc_server'
require_relative 'lib/signal_handler'

if $PROGRAM_NAME == __FILE__
  
  SignalHandler.trap('INT', 'TERM') do
    puts "\nReceived shutdown signal, stopping gracefully..."
    server.stop
  end
  
  registry = ServiceRegistry.instance
  registry.register(UserAPIGatewayService, UserAPIGatewayServiceHandler)
  #TODO add more services here

  server = GrpcServer.new

  begin
    puts "Starting gRPC server on #{ConfigHandler.instance.config[:bind]}"
    server.run
  rescue StandardError => e
    puts "Failed to start server: #{e.message}"
    exit 1
  end
end