# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ApiGateway.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/23 20:39:15 by craimond          #+#    #+#              #
#    Updated: 2024/11/01 19:11:42 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'ConfigLoader'
require_relative 'GrpcClient'
require_relative 'Logger'
require_relative 'Server'

class APIGateway
  def initialize(config_file)
    @config_loader = ConfigLoader.new(config_file)
    @config_loader.load_config
    Logger.create_logger($LOG_LEVEL, $LOG_FILE)
    @worker_pid = nil
    @logger = Logger.logger
  rescue StandardError => e
    STDERR.puts "Error during initialization: #{e.message}"
    exit 1
  end

  def start_master
    @logger.info('Starting master process...')
    master_pid = Process.pid
    @logger.debug("Master process PID: #{master_pid}")
    File.write('/run/api-gateway.pid', master_pid)

    Signal.trap('SIGHUP') { reload_config }
    Signal.trap('SIGTERM') { shutdown }

    @logger.info('Starting worker process...')
    spawn_worker

    sleep
  rescue StandardError => e
    @logger.fatal("Error during master process: #{e.message}")
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
    @config_loader.load_configs
    if @worker_pid
      Process.kill('TERM', @worker_pid)
      Process.wait(@worker_pid)
      spawn_worker
    end
  rescue StandardError => e
    @logger.error("Error during config reload: #{e.message}")
  end

  def shutdown
    @logger.info('Shutting down...')
    if @worker_pid
      @logger.debug('Terminating worker process {}'.format(@worker_pid))
      Process.kill('TERM', @worker_pid)
      @logger.debug('Waiting for worker process {} to terminate'.format(@worker_pid))
      Process.wait(@worker_pid)
    end
    exit 0
  rescue StandardError => e
    @logger.fatal("Error during shutdown: #{e.message}")
    exit 1
  end
end
