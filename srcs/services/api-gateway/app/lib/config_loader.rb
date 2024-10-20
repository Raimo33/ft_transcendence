# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    config_loader.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:22 by craimond          #+#    #+#              #
#    Updated: 2024/10/20 11:35:02 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class ConfigLoader
  def initialize
    @config = {}
  end

  def load_configs(config_dir)
    needs_restart = false

    Dir.glob("#{config_dir}/*.conf").each do |config_file|
      begin
        validate_config_file(config_file)
        new_config = parse_config_file(config_file)
        needs_restart ||= (new_config['bind_address'] != @config['bind_address'] || new_config['bind_port'] != @config['bind_port'])
        @config.merge!(new_config)
      rescue StandardError => e
        STDERR.puts "Error loading config from file '#{config_file}': #{e.message}"
      end
    end
    
    apply_config
    needs_restart
  end

  private

  def validate_config_file(file_path)
    #TODO check file name extension (expected: '.conf')
    #TODO key and value are admitted (key exists in the ones expected, value is formatted correctly)
    #throw exception

  def parse_config_file(file_path)
    config = {}
    File.readlines(file_path).each do |line|
      key, value = line.strip.split('=', 2)
      config[key.strip] = value.strip if key && value
    end
    config
  end

  def apply_config
    @config.each do |key, value|
      case key
      when 'bind_address'
        $BIND_ADDRESS = value
      when 'bind_port'
        $BIND_PORT = value
      when 'keycloak_host'
        $KEYCLOAK_HOST = value
      when 'keycloak_realm'
        $KEYCLOAK_REALM = value
      when 'keycloak_certs'
        $KEYCLOAK_CERTS = value
      when 'jwt_cache_expiry'
        $JWT_CACHE_EXPIRY = value.to_i
      when 'jwt_algorithm'
        $JWT_ALGORITHM = value
      when 'thread_pool_size'
        $THREAD_POOL_SIZE = value.to_i
      end
    end
  end
end
