# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    main.rb                                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:13 by craimond          #+#    #+#              #
#    Updated: 2024/10/22 17:21:33 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'lib/server'
require_relative 'lib/config_loader'

begin
  config_dir = '/shared/conf'
  pid_file = '/run/api-gateway.pid'

  File.write(pid_file, Process.pid)
  config_loader = ConfigLoader.new
  config_loader.load_configs(config_dir)

  grpc_client = GrpcClient.new
  server = Server.new(grpc_client)

  Signal.trap('SIGHUP') do
    begin
      if config_loader.load_configs(config_dir)
        server.stop
        server = Server.new
        server.run
      end
    rescue StandardError => e
      STDERR.puts "Error reloading configuration: #{e.message}"
    end
  end

  Signal.trap('SIGTERM') do
    begin
      server.stop
      exit 0
    rescue StandardError => e
      STDERR.puts "Error during shutdown: #{e.message}"
      exit 1
    end
  end

  server.run

rescue => e
  STDERR.puts "Fatal Error: #{e.message}"
  exit 1
end
