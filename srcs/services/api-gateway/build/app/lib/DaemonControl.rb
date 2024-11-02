# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    DaemonControl.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/02 16:45:58 by craimond          #+#    #+#              #
#    Updated: 2024/11/02 18:34:09 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'optparse'
require_relative 'ConfigLoader'
require_relative 'APIGateway'

#TODO handle -t to test conf

class DaemonControl
  include ConfigLoader

  DEFAULT_CONFIG_FILE = '/etc/api-gateway/conf.d/default.conf'
  DEFAULT_PID_FILE = '/var/run/api-gateway.pid'

  def initialize(args)
    @options = parse_options(args)
    @config_file = @options[:config_file] || DEFAULT_CONFIG_FILE
    @config = ConfigLoader.load_minimal(@config_file)
  end

  def run
    unless @options[:signal]
      start_daemon
    else
      unless ['stop', 'reload'].include?(@options[:signal])
        STDERR.puts "Invalid signal: #{@options[:signal]}"
        STDERR.puts "Valid signals are: stop, reload"
        exit 1
      end

      signal = @options[:signal] == 'reload' ? 'HUP' : 'TERM'
      send_signal(signal)
    end
  end

  private

  def parse_options(args)
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$PROGRAM_NAME} [-c config] [-s signal]"
      
      opts.on('-c CONFIG', '--config CONFIG', 'Configuration file path') do |config|
        options[:config_file] = config
      end
      
      opts.on('-s SIGNAL', '--signal SIGNAL', 'Send signal to master process (reload|stop)') do |signal|
        options[:signal] = signal
      end
    end

    parser.parse!(args)
    options
  end

  def start_daemon
    daemonize

    ConfigLoader.load(@config_file)
    File.write(@config[:pid_file], Process.pid)

    begin
      APIGateway.new.start_master
    ensure
      File.unlink(@config[:pid_file]) if File.exist?(@config[:pid_file])
    end
  rescue StandardError => e
    STDERR.puts "Error during daemon startup: #{e.message}"
  end

  def send_signal(signal)
    pid = read_pid
    unless pid
      puts "Cannot read PID file #{@config[:pid_file]} or process is not running"
      exit 1
    end

    begin
      Process.kill(signal, pid)
      puts "Sent #{signal} signal to process #{pid}"
    rescue StandardError => e
      puts "Failed to send signal: #{e.message}"
      exit 1
    end
  end

  def daemonize
    exit if fork
    Process.setsid
    exit if fork

    Dir.chdir '/'
    File.umask 0000

    STDIN.reopen '/dev/null'
    STDOUT.reopen '/dev/null', 'a'
    STDERR.reopen '/dev/null', 'a'
  end

  def read_pid
    return nil unless File.exist?(@config[:pid_file])
    pid = File.read(@config[:pid_file]).to_i
    Process.kill(0, pid)
    pid
  rescue Errno::ESRCH, Errno::EPERM
    nil
  end

end