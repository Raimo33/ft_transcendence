require_relative 'lib/server'

begin

Server.new.run

rescue => e
    STDERR.puts "Fatal Error: #{e.message}"
