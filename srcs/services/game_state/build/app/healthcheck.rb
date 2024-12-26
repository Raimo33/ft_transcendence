#!/usr/bin/env ruby

require 'grpc'
require_relative 'protos/match_api_gateway_services_pb'
require_relative 'protos/match_game_state_services_pb'
require_relative 'protos/match_matchmaking_services_pb'

if $PROGRAM_NAME == __FILE__
  stubs = {
    #TODO stubs
  }

  stubs.each do |service, stub|
    stub.ping(Empty.new)
    puts "#{service} service is healthy"
  rescue GRPC::Unavailable
    puts "#{service} service is unhealthy"
    exit 1
  rescue => e
    puts "#{service} service is unhealthy: #{e.message}"
    exit 1
  end
  exit 0
end