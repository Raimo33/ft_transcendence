# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Launcher.rb                                        :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/02 16:45:58 by craimond          #+#    #+#              #
#    Updated: 2024/11/08 22:39:39 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "optparse"
require_relative "Orchestrator.rb"
require_relative "./modules/ConfigLoader"

class Launcher
  include ConfigLoader

  DEFAULT_CONFIG_FILE = "/etc/user/conf.d/default.conf"
  DEFAULT_PID_FILE = "/var/run/user.pid"

  def initialize(args)
    @options = parse_options(args)
    @config_file = @options[:config_file] || DEFAULT_CONFIG_FILE

    minimal_config = ConfigLoader.load_minimal(@config_file)
    @pid_file = config[:pid_file] || DEFAULT_PID_FILE
  rescue StandardError => e
    STDERR.puts "Error during initialization: #{e}"
    exit 1
  end

  def run
    if @options[:test]
      test_config
    elsif @options[:signal]
      handle_signal
    else
      launch
    end
  end

  private

  def parse_options(args)
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$PROGRAM_NAME} [-c config] [-s signal]"
      
      opts.on("-c CONFIG", "--config CONFIG", "Configuration file path") do |config|
        options[:config_file] = config
      end
      
      opts.on("-s SIGNAL", "--signal SIGNAL", "Send signal to master process (reload|stop)") do |signal|
        options[:signal] = signal
      end

      opts.on("-t", "--test", "Test the configuration and exit") do
        options[:test] = true
      end
    end

    parser.parse!(args)
    options
  end

  def launch
    ConfigLoader.load(@config_file)
    File.write(@@pid_file, Process.pid)

    begin
      Orchestrator.new.start_master
    ensure
      File.unlink(@@pid_file) if File.exist?(@@pid_file)
    end
  rescue StandardError => e
    STDERR.puts "Error during startup: #{e}"
  end

  def test_config
    begin
      ConfigLoader.load(@config_file)
      puts "Configuration file #{@config_file} is valid."
    rescue StandardError => e
      STDERR.puts "Configuration file test failed: #{e}"
      exit 1
    end
    exit 0
  end

  def handle_signal
    unless %w[stop reload].include?(@options[:signal])
      STDERR.puts "Invalid signal: #{@options[:signal]}"
      STDERR.puts "Valid signals are: stop, reload"
      exit 1
    end

    signal = @options[:signal] == "reload" ? "HUP" : "TERM"
    send_signal(signal)
  end

  def send_signal(signal)
    pid = read_pid
    unless pid
      puts "Cannot read PID file #{@@pid_file} or process is not running"
      exit 1
    end

    begin
      Process.kill(signal, pid)
      puts "Sent #{signal} signal to process #{pid}"
    rescue StandardError => e
      puts "Failed to send signal: #{e}"
      exit 1
    end
  end

  def read_pid
    return nil unless File.exist?(@@pid_file)
    pid = File.read(@@pid_file).to_i
    Process.kill(0, pid)
    pid
  rescue Errno::ESRCH, Errno::EPERM
    nil
  end

end