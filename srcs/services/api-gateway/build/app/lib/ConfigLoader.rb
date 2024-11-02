# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ConfigLoader.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:22 by craimond          #+#    #+#              #
#    Updated: 2024/11/02 16:13:45 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class ConfigLoader

  VALID_CONFIG_KEYS = {
    'bind_address'                  => ->(value) { $BIND_ADDRESS = value },
    'bind_port'                     => ->(value) { $BIND_PORT = value.to_i },
    'pid_file'                      => ->(value) { $PID_FILE = value },
    'keycloak_pub_key_url'          => ->(value) { $KEYCLOAK_PUB_KEY_URL = value },
    'jwt_pub_key_ttl'               => ->(value) { $JWT_PUB_KEY_TTL = value.to_i },
    'jwt_algorithm'                 => ->(value) { $JWT_ALGORITHM = value },
    'jwt_expiry_leeway'             => ->(value) { $JWT_EXPIRY_LEEWAY = value.to_i },
    'jwt_audience'                  => ->(value) { $JWT_AUDIENCE = value },
    'max_connections'               => ->(value) { $MAX_CONNECTIONS = value.to_i },
    'max_body_size'                 => ->(value) { $MAX_BODY_SIZE = value.to_i },
    'user_server_cert'              => ->(value) { $USER_SERVER_CERT = value },
    'match_server_cert'             => ->(value) { $MATCH_SERVER_CERT = value },
    'tournament_server_cert'        => ->(value) { $TOURNAMENT_SERVER_CERT = value },
    'user_grpc_server_addr'         => ->(value) { $USER_GRPC_SERVER_ADDR = value },
    'match_grpc_server_addr'        => ->(value) { $MATCH_GRPC_SERVER_ADDR = value },
    'tournament_grpc_server_addr'   => ->(value) { $TOURNAMENT_GRPC_SERVER_ADDR = value },
    'log_level'                     => ->(value) { $LOG_LEVEL = value }
    'log_file'                      => ->(value) { $LOG_FILE = value }
  }.freeze

  def initialize(config_file)
    @config_file = config_file
    @config = {}
  end

  def load_config
    validate_config_file(config_file)
    @config = parse_config_file(config_file)

    apply_config
  rescue StandardError => e
    raise "Error loading config: #{e}"
  end

  private

  def validate_config_file(file_path)
    raise "Invalid config file extension" unless File.extname(file_path) == '.conf'

    provided_config = parse_config_file(file_path)
    provided_config.each do |key, value|
      raise "Invalid config key: #{key}" unless VALID_CONFIG_KEYS.keys.include?(key)
    end
  end

  def parse_config_file(file_path)
    config = {}
    File.readlines(file_path).each do |line|
      stripped_line = line.strip
      next if stripped_line.empty? || stripped_line.start_with?('#')
      key, value = stripped_line.split('=', 2)
      raise "Invalid config line: #{line}" unless key && value
      config[key.strip] = value.strip if key && value
    end
    config
  end

  def apply_config
    @config.each do |key, value|
      VALID_CONFIG_KEYS[key].call(value)
    end
  end
end
