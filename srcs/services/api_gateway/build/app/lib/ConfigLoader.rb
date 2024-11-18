# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ConfigLoader.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/10 15:33:59 by craimond          #+#    #+#              #
#    Updated: 2024/11/18 17:40:59 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'set'
require 'yaml'

#TODO studiare safe_load di yaml

class ConfigLoader
  include Singleton

  attr_reader :config, :config_file

  REQUIRED_KEYS =
  {
    bind:     String,
    pid_file: String,
    logging:
    {
      level:  String,
      file:   String
      tag:    String
    },
    jwt:
    {
      key_refresh_interval: Integer,
      clock_skew:           Integer,
      audience:             String
    },
    limits: {
      max_connections:  Integer,
    },
    addresses:
    {
      user:       String,
      match:      String,
      tournament: String,
      auth:       String
    }
  }.freeze

  def initialize
    @config_file = nil
    @config = nil
  end

  def load(config_file:)
    raise "Config file #{config_file} does not exist" unless File.exist?(config_file)

    @config_file = config_file
    @config = YAML.load_file(@config_file)
    validate
  rescue StandardError => e
    raise "Error loading config file #{@config_file}: #{e.message}"
  end

  def reload
    load(@config_file)
  end

  private

  def validate
    raise "Config cannot be empty" if @config.nil?
    
    REQUIRED_KEYS.each do |key, spec|
      raise "Missing required key: #{key}" unless @config.key?(key)
      
      if spec.is_a?(Hash)
        raise "Value for #{key} must be a Hash" unless @config[key].is_a?(Hash)
        spec.each do |subkey, type|
          raise "Missing #{key}.#{subkey}" unless @config[key].key?(subkey)
          raise "#{key}.#{subkey} must be a #{type}" unless @config[key][subkey].is_a?(type)
        end
      else
        raise "#{key} must be a #{spec}" unless @config[key].is_a?(spec)
      end
    end
  end 

end
