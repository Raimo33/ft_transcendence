#!/usr/bin/env ruby

require 'grpc'
require_relative 'proto/matchmaking_match_services_pb'
#TODO aggiungere altri stubs

if $PROGRAM_NAME == __FILE__
  stubs = {
    matchmaking_match: MatchmakingMatch::Stub.new('localhost:50051', :this_channel_is_insecure),
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