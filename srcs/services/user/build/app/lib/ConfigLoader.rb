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
      file:  String,
      tag:   String
    },
  
    addresses:
    {
      auth:       String,
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

  def validate(schema = REQUIRED_KEYS, config = @config, path = [])
    raise "Config cannot be empty" if config.nil?
    
    schema.each do |key, spec|
      current_path = path + [key]
      path_str = current_path.join('.')
      
      unless config.key?(key)
        raise "Missing required key: #{path_str}"
      end

      validate_value(config[key], spec, current_path)
    end
  end

  def validate_value(value, spec, path)
    path_str = path.join('.')

    case spec
    when Hash
      unless value.is_a?(Hash)
        raise "Value for #{path_str} must be a Hash, got #{value.class}"
      end
      validate(spec, value, path)
    when Array
      unless value.is_a?(Array)
        raise "Value for #{path_str} must be an Array, got #{value.class}"
      end
      
      if spec.size == 1
        element_type = spec.first
        value.each_with_index do |element, index|
          validate_value(element, element_type, path + [index])
        end
      end
    when Class
      unless value.is_a?(spec)
        raise "#{path_str} must be a #{spec}, got #{value.class}"
      end
    else
      raise "Invalid schema specification for #{path_str}"
    end
  end

end