# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ConfigLoader.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:22 by craimond          #+#    #+#              #
#    Updated: 2024/11/05 17:38:04 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

module ConfigLoader

  VALID_CONFIG_KEYS = {
    :bind_address                 => 'localhost',
    :bind_port                    => 8080,
    :pid_file                     => '/var/run/api-gateway.pid',
    :keycloak_pub_key_url         => nil,
    :jwt_pub_key_ttl              => 3600,
    :jwt_algorithm                => 'RS256',
    :jwt_clock_skew               => 60,
    :jwt_audience                 => 'localhost',
    :max_connections              => 1024,
    :max_body_size                => 1024 * 1024,
    :user_server_cert             => nil,
    :match_server_cert            => nil,
    :tournament_server_cert       => nil,
    :user_grpc_server_addr        => nil,
    :match_grpc_server_addr       => nil,
    :tournament_grpc_server_addr  => nil,
    :log_level                    => 'INFO',
    :log_file                     => '/var/log/api-gateway.log',
  }.freeze

  def self.load(config_file)
    raise "Invalid config file extension" unless File.extname(config_file) == '.conf'
    raise "Config file #{config_file} does not exist" unless File.exist?(config_file)

    @config_file = config_file
    config = {}
    File.readlines(config_file).each do |line|
      stripped_line = line.strip
      next if stripped_line.empty? || stripped_line.start_with?('#')
      key, value = stripped_line.split('=', 2)
      raise "Invalid config line: #{line}" unless key && value
      config[key.strip] = value.strip if key && value
    end

    validate(config)
  end

  def self.load_minimal(config_file)
    raise "Invalid config file extension" unless File.extname(config_file) == '.conf'
    raise "Config file #{config_file} does not exist" unless File.exist?(config_file)

    config = {}
    File.foreach(config_file) do |line|
      case line.strip
      when /^pid_file\s*=\s*["']?([^"']+)["']?/
        config[:pid_file] = $1
      end
      # Add other critical paths as needed
    end

    config
  end

  def self.reload
    load(@config_file)
  end
  
  def self.config
    @config ||= load_config
  end
  
  private

  def self.validate(config)
    unknown_keys = config.keys - VALID_CONFIG_KEYS.keys
    raise "Unknown config keys: #{unknown_keys.join(', ')}" unless unknown_keys.empty?

    VALID_CONFIG_KEYS.each do |key, default_value|
      config[key] = default_value if config[key].nil? && !default_value.nil?
    end

    missing_keys = VALID_CONFIG_KEYS.select { |key, default_value| default_value.nil? && !config.key?(key) }.keys
    raise "Missing required config keys: #{missing_keys.join(', ')}" unless missing_keys.empty?

    config.each do |key, value|
      next unless VALID_CONFIG_KEYS.key?(key)

      case VALID_CONFIG_KEYS[key]
      when Integer
        config[key] = value.to_i
      when Float
        config[key] = value.to_f
      when TrueClass, FalseClass
        config[key] = %w[true yes].include?(value.downcase)
      else
        config[key] = value
      end
    end

    config
  end
end

end
