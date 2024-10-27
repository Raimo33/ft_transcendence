# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ConfigLoader.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:22 by craimond          #+#    #+#              #
#    Updated: 2024/10/27 17:52:56 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

#TODO reduce redundancy, error possibilities with keeping arrays of valid keys
class ConfigLoader
  VALID_KEYS = %i[
    bind_address
    bind_port
    keycloak_pub_key_url
    jwt_pub_key_ttl
    jwt_algorithm
    jwt_expiry_leeway
    max_connections
    max_body_size
    user_server_cert
    match_server_cert
    tournament_server_cert
  ].freeze

  def initialize(config_file)
    @config_file = config_file
    @config = {}
  end

  def load_config
    validate_config_file(config_file)
    @config = parse_config_file(config_file)

    apply_config
  end

  private

  #TODO better config validation, account for comments and empty lines
  def validate_config_file(file_path)
    raise "Invalid file extension" unless File.extname(file_path) == '.conf'

    File.readlines(file_path).each do |line|
      key, value = line.strip.split('=', 2)
      raise "Invalid key: #{key}" unless VALID_KEYS.include?(key.strip)
      raise "Invalid value for key: #{key}" if value.strip.empty?
    end
  end

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
      when 'keycloak_pub_key_url'
        $KEYCLOAK_PUB_KEY_URL = value
      when 'jwt_pub_key_ttl'
        $JWT_PUB_KEY_TTL = value.to_i
      when 'jwt_algorithm'
        $JWT_ALGORITHM = value
      when 'jwt_expiry_leeway'
        $JWT_EXPIRY_LEEWAY = value.to_i
      when 'max_connections'
        $MAX_CONNECTIONS = value.to_i
      when 'max_body_size'
        $MAX_BODY_SIZE = value.to_i
      when 'user_server_cert'
        $USER_SERVER_CERT = value
      when 'match_server_cert'
        $MATCH_SERVER_CERT = value
      when 'tournament_server_cert'
        $TOURNAMENT_SERVER_CERT = value
      end
    end
  end
end
