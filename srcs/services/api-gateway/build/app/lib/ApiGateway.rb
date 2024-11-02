# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ApiGateway.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/23 20:39:15 by craimond          #+#    #+#              #
#    Updated: 2024/11/02 16:12:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'ConfigLoader'
require_relative 'GrpcClient'
require_relative 'Logger'
require_relative 'Server'

class APIGateway
  def initialize(config_file)
    @logger = Logger.new(STDOUT)
    @config_loader = ConfigLoader.new(config_file)
    @config_loader.load_config  
    @worker_pid = nil
    @current_pid_file = $PID_FILE
    @master_pid = Process.pid

    @logger.close
    Logger.create_logger($LOG_LEVEL, $LOG_FILE)
    @logger = Logger.logger

    File.write(@current_pid_file, @master_pid)
  rescue StandardError => e
    @logger.fatal("Error during initialization: #{e.message}")
    @logger.debug(e.backtrace.join("\n"))
    exit 1
  end

  def start_master
    Signal.trap('SIGHUP') { reload_config }
    Signal.trap('SIGTERM') { shutdown }

    @logger.info('Starting worker process...')
    spawn_worker

    sleep
  rescue StandardError => e
    @logger.fatal("Error during master process: #{e.message}")
    @logger.debug(e.backtrace.join("\n"))
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
    return unless @config_loader.configs_changed?   

    if $PID_FILE != @current_pid_file
      File.delete(@current_pid_file) if File.exist?(@current_pid_file)
      File.write($PID_FILE, @master_pid)
      @current_pid_file = $PID_FILE
    end

    if @worker_pid
      Process.kill('TERM', @worker_pid)
      Process.wait(@worker_pid)
      spawn_worker
    end
  rescue StandardError => e
    @logger.error("Error during config reload: #{e.message}\nContinuing with old configuration")
    @logger.debug(e.backtrace.join("\n"))
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
    @logger.fatal("Error during graceful shutdown: #{e.message}")
    @logger.debug(e.backtrace.join("\n"))
  ensure
    File.delete(@current_pid_file) if File.exist?(@current_pid_file)
    exit 1
  end
end
