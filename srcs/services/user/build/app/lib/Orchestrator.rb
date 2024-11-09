# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Orchestrator.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/23 20:39:15 by craimond          #+#    #+#              #
#    Updated: 2024/11/08 22:39:39 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative "GrpcClient"
require_relative "Server"
require_relative "./modules/Logger"
require_relative "./modules/ConfigLoader"

class Orchestrator
  include ConfigLoader
  include Logger

  def initialize
    @logger = Logger.new(STDOUT)

    @config = ConfigLoader.config
    @worker_pid = nil
    @master_pid = Process.pid

    @logger.close
    Logger.create(@config[:log_file], @config[:log_level])
    @logger = Logger.logger

  rescue StandardError => e
    @logger.fatal("Error during initialization: #{e}")
    @logger.debug(e.backtrace.join("\n"))
    exit 1
  end

  def start_master
    Signal.trap("SIGHUP") { reload_config }
    Signal.trap("SIGTERM") { shutdown }

    @logger.info("Starting worker process...")
    spawn_worker

    sleep
  rescue StandardError => e
    @logger.fatal("Error during master process: #{e}")
    @logger.debug(e.backtrace.join("\n"))
  end

  private

  def spawn_worker
    @worker_pid = Process.fork do
      server = GrpcServer.new
      server.run
    end
  end

  def reload_config
    new_config = config_loader.reload
    return unless new_config.values != @config.values

    current_pid_file, new_pid_file = @config[:pid_file], new_config[:pid_file]
    if current_pid_file != new_pid_file
      File.delete(current_pid_file) if File.exist?(current_pid_file)
      File.write(new_pid_file, @master_pid)
    end

    @config = new_config

    if @worker_pid
      Process.kill("TERM", @worker_pid)
      Process.wait(@worker_pid)
      spawn_worker
    end
  rescue StandardError => e
    @logger.error("Error during config reload: #{e}")
    @logger.info("Continuing with current configuration")
  end

  def shutdown
    @logger.info("Shutting down...")
    if @worker_pid
      @logger.debug("Terminating worker process {}".format(@worker_pid))
      Process.kill("TERM", @worker_pid)
      @logger.debug("Waiting for worker process {} to terminate".format(@worker_pid))
      Process.wait(@worker_pid)
    end
    exit 0
  rescue StandardError => e
    @logger.fatal("Error during graceful shutdown: #{e}")
    @logger.debug(e.backtrace.join("\n"))
  ensure
    File.delete(@current_pid_file) if File.exist?(@current_pid_file)
    exit 1
  end
end
