#!/usr/bin/env ruby

require 'grpc'
require_relative 'proto/auth_services_pb'

if $PROGRAM_NAME == __FILE__
  stubs = {
    user: Auth::Stub.new(
      'localhost:50052',
      :this_channel_is_insecure
    )
  }

  stubs.each do |service, stub|
    stub.ping(Google::Protobuf::Empty.new)
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