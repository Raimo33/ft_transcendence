#!/usr/bin/env ruby

require_relative 'lib/grpc_server'
require_relative 'lib/service_registry'

if $PROGRAM_NAME == __FILE__

  registry = ServiceRegistry.instance
  registry.register(UserAPIGateway, UserAPIGatewayServiceHandler)
  #add more services here

  server = GrpcServer.new

  server.run
rescue StandardError => e
  puts "Uknown error: #{e}"
  exit 1
end