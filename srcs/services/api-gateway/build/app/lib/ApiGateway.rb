# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ApiGateway.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/23 20:39:15 by craimond          #+#    #+#              #
#    Updated: 2024/10/27 18:02:50 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'config_loader'
require 'grpc_client'
require 'server'

class APIGateway
  def initialize(config_file)
    @config_loader = ConfigLoader.new(config_file).load_configs
    @worker_pid = nil
  end

  def start_master
    File.write('/run/api-gateway.pid', Process.pid)

    Signal.trap('SIGHUP') { reload_config }
    Signal.trap('SIGTERM') { shutdown }

    spawn_worker

    sleep
  end

  private

  def spawn_worker
    @worker_pid = Process.fork do
      grpc_client = GrpcClient.new
      server = Server.new(grpc_client)
      server.run 
    end
  end

  def reload_config
    begin
      @config_loader.load_configs
      if @worker_pid
        Process.kill('TERM', @worker_pid)
        Process.wait(@worker_pid)
        spawn_worker
      end
    end
  end

  def shutdown
    begin
      if @worker_pid
        Process.kill('TERM', @worker_pid)
        Process.wait(@worker_pid)
      end
      exit 0
    rescue StandardError => e
      STDERR.puts "Error during shutdown: #{e.message}"
      exit 1
    end
  end
end
