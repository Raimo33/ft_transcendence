require 'singleton'
require 'set'
require 'yaml'

class ConfigLoader
  include Singleton

  REQUIRED_KEYS =
  {
    bind:     String,
    pid_file: String,
    
    logging:
    {
      level: String,
      file:  String
    },
  
    credentials:
    {
      keys:
      {
        user: String
      },
      certs:
      {
        user:       String,
        db_gateway: String, 
        auth:       String,
        redis: String
      }
    },
  
    addresses:
    {
      db_gateway: String,
      auth:       String,
      redis: String
    },
  
    display_name:
    {
      min_length: Integer,
      max_length: Integer,
      charset:
      {
        lowercase: String,
        uppercase: String,
        digits:    String,
        special:   String
      },
      policy:
      {
        min_uppercase: Integer,
        min_lowercase: Integer,
        min_digits:    Integer,
        min_special:   Integer
      },
      banned_words_file: String
    },
  
    password:
    {
      min_length: Integer,
      max_length: Integer,
      charset:
      {
        lowercase: String,
        uppercase: String,
        digits:    String,
        special:   String
      },
      policy:
      {
        min_uppercase: Integer,
        min_lowercase: Integer,
        min_digits:    Integer,
        min_special:   Integer
      },
      banned_passwords_file: String
    }

    avatar:
    {
      max_size: Integer,
      max_dimensions:
      {
        width:  Integer,
        height: Integer
      },
      allowed_types: Set[String],
      default_file:  String
    }

  }.freeze

  def initialize
    @config_file = nil
    @config = nil
  end

  def load(config_file)
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
