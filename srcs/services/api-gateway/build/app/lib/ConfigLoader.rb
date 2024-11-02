# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ConfigLoader.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:22 by craimond          #+#    #+#              #
#    Updated: 2024/11/02 18:37:09 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'set'

module Config

  VALID_CONFIG_KEYS = Set.new([
    :bind_address,
    :bind_port,
    :pid_file,
    :keycloak_pub_key_url,
    :jwt_pub_key_ttl,
    :jwt_algorithm,
    :jwt_clock_skew,
    :jwt_audience,
    :max_connections,
    :max_body_size,
    :user_server_cert,
    :match_server_cert,
    :tournament_server_cert,
    :user_grpc_server_addr,
    :match_grpc_server_addr,
    :tournament_grpc_server_addr,
    :log_level,
    :log_file,
  ]).freeze

  def self.load(config_file)
    raise "Invalid config file extension" unless File.extname(config_file) == '.conf'

    @config_file = config_file
    config = {}
    File.readlines(config_file).each do |line|
      stripped_line = line.strip
      next if stripped_line.empty? || stripped_line.start_with?('#')
      key, value = stripped_line.split('=', 2)
      raise "Invalid config line: #{line}" unless key && value
      config[key.strip] = value.strip if key && value
    end

    provided_config.each do |key, value|
      raise "Invalid config key: #{key}" unless VALID_CONFIG_KEYS.include?(key)

    config
  end

  def self.load_minimal(config_file) #TODO capire, migliorare, error handling
    config = {}
    
    File.foreach(config_file) do |line|
      case line.strip
      when /^pid_file\s*=\s*["']?([^"']+)["']?/
        config[:pid_file] = $1
      end
      # Add other critical paths as needed
    end

    config[:pid_file] ||= DEFAULT_PID_FILE
    config
  end

  def self.reload
    load(@config_file)
  end

  def self.config
    @config ||= load_config
  end

end
