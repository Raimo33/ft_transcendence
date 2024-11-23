# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    RequestParser.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/20 06:06:29 by craimond          #+#    #+#              #
#    Updated: 2024/11/23 13:23:57 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative "modules/Structs"
require 'zlib'
require 'stringio'

#TODO validations dello schema di expected_path_params e expected_query_params e expected_headers e body

class RequestParser
  STATES = %i[FIRST_LINE HEADERS BODY COMPLETE].freeze
  RECOGNISED_METHODS = %i[GET POST PUT PATCH DELETE].freeze
  SUPPORTED_ENCODINGS = %i[compress deflate gzip identity].freeze

  def initialize
    @config  = ConfigurableLogger.instance.config
    @logger  = ConfigurableLogger.instance.logger

    @state            = STATES.first
    @partial_request  = Request.new
    @expected_request = nil
  end

  def parse_request(buffer)
    case @state
    when :FIRST_LINE
      return parse_first_line_state(buffer)
    when :HEADERS
      return parse_headers_state(buffer)
    when :BODY
      return parse_body_state(buffer)
    end

    if @state == :COMPLETE
      request = @partial_request
      reset_parser
      return request
    end

    nil
  end

  private

  def reset_parser
    @partial_request = Request.new
    @state = STATES.first
  end

  def parse_first_line_state(buffer)
    return nil unless buffer.include?("\r\n")
    parse_first_line(buffer)
    advance_buffer(buffer, "\r\n")
    @state = :HEADERS
    nil
  end

  def parse_headers_state(buffer)
    return nil unless buffer.include?("\r\n\r\n")
    parse_headers(buffer)
    advance_buffer(buffer, "\r\n\r\n")
    @state = :BODY
    nil
  end

  def parse_body_state(buffer)
    transfer_encodings = parse_transfer_encodings
    
    if transfer_encodings.include?(:chunked)
      return nil unless parse_chunked_body(buffer)
    else
      return nil unless parse_regular_body(buffer)
    end
    #TODO controllare se required: true
    decode_body(transfer_encodings)
    validate_body(@partial_request.body, @resource.expected_request.body_schema)
    @state = :COMPLETE
    nil
  end

  def parse_first_line(buffer)
    first_line = buffer.split("\r\n").first
    raise ServerException::BadRequest.new("Missing first line") unless first_line

    words = first_line.split
    raise ServerException::BadRequest.new("Invalid first line") unless words.size == 3

    @partial_request.method = words[0].upcase.to_sym
    raise ServerException::BadRequest.new("Invalid method") unless RECOGNISED_METHODS.include?(@partial_request.method)

    full_path = words[1]
    raise ServerException::BadRequest.new("Invalid path") unless full_path
    raw_path, raw_query = full_path.split("?")
    raise ServerException::BadRequest.new("Invalid path") unless raw_path

    @resource = @resource_tree.find(http_method, raw_path)
    raise ServerException::NotFound.new("Resource not found") unless @resource
    
    @partial_request.path_params  = parse_path_params(raw_path, @resource.path, @resource.expected_request.allowed_path_params)
    @partial_request.query_params = parse_query_params(raw_query, @resource.expected_request.allowed_query_params)
  end

  def parse_path_params(raw_path, expected_path, allowed_path_params)
    raw_segments      = raw_path.split('/')
    expected_segments = expected_path.split('/')
    
    raise ServerException::BadRequest.new("Path mismatch") unless raw_segments.size == expected_segments.size
    
    path_params = {}
    
    raw_segments.zip(expected_segments).each do |raw, expected|    
      if expected&.start_with?('{') && expected&.end_with?('}')
        param_name = expected[1..-2].to_sym
        path_params[param_name] = raw
      elsif raw != expected
        raise ServerException::BadRequest.new("Path mismatch")
      end
    end    
    
    path_params
  end

  def parse_query_params(raw_query, allowed_query_params)    
    query_params = {}
    
    if raw_query && !raw_query.empty?
      raw_params = raw_query.split('&')
      
      raw_params.each do |param|
        key, value = param.split('=', 2)
        next unless key && value
        
        decoded_key   = URI.decode_www_form_component(key)
        decoded_value = URI.decode_www_form_component(value)
        
        param_config = allowed_query_params[decoded_key.to_sym]
        next unless param_config
        
        query_params[decoded_key.to_sym] = parse_param_value(decoded_value, param_config)
      end
    end

    allowed_query_params.each do |param_name, config|
      if config[:required] && !query_params.key?(param_name)
        raise ServerException::BadRequest.new("Missing required query parameter: #{param_name}")
      end
    end
    
    query_params
  end

  def parse_param_value(value, config)
    return value if value.nil?
  
    case config[:style]
    when 'spaceDelimited'
      parse_space_delimited(value, config)
    when 'pipeDelimited'
      parse_pipe_delimited(value, config)
    when 'deepObject'
      parse_deep_object(value, config)
    else
      parse_form_style(value, config)
    end
  end

  def parse_form_style(value, config)
    case config.dig(:schema, :type)
    when 'array'
      config[:explode] ? [value] : value.split(',')
    when 'object'
      if config[:explode]
        value.split('&').each_with_object({}) do |pair, hash|
          k, v = pair.split('=')
          hash[k.to_sym] = v
        end
      else
        parts = value.split(',')
        Hash[parts.each_slice(2).map { |k, v| [k.to_sym, v] }]
      end
    else
      value
    end
  end
  
  def parse_space_delimited(value, config)
    return value unless config.dig(:schema, :type) == 'array'
    value.split(' ')
  end
  
  def parse_pipe_delimited(value, config)
    return value unless config.dig(:schema, :type) == 'array'
    value.split('|')
  end
  
  def parse_deep_object(value, config)
    return value unless config.dig(:schema, :type) == 'object'
    
    if value.include?('[') && value.include?(']')
      key = value[/\[(.*?)\]/, 1]
      val = value.split('=').last
      { key.to_sym => val }
    else
      value
    end
  end

  def parse_headers(buffer)
    headers_block = buffer.split("\r\n\r\n").first
    raise ServerException::BadRequest.new("Missing headers") unless headers_block
  
    headers = headers_block.split("\r\n")
    parsed_headers = {}
    allowed_headers = @resource.expected_request.allowed_headers
  
    headers.each do |header|
      key, value = header.split(": ")
      next unless key && value
      header_key = key.downcase.to_sym
      
      if allowed_headers.key?(header_key)
        config = allowed_headers[header_key]
        parsed_headers[header_key] = parse_header_value(value, config)
      end
    end
  
    allowed_headers.each do |header_name, config|
      if config[:required] && !parsed_headers.key?(header_name)
        raise ServerException::BadRequest.new("Missing required header: #{header_name}")
      end
    end
  
    @partial_request.headers = parsed_headers
  end

  def parse_header_value(value, config)
    return value if value.nil?
  
    case config.dig(:schema, :type)
    when 'array'
      if config[:explode]
        value.split(',').map(&:strip)
      else
        [value]
      end
    when 'object'
      if config[:explode]
        value.split(',').each_with_object({}) do |pair, hash|
          k, v = pair.split('=')
          hash[k.to_sym] = v
        end
      else
        parts = value.split(',')
        Hash[parts.each_slice(2).map { |k, v| [k.to_sym, v] }]
      end
    else
      value
    end
  end

  def parse_transfer_encodings
    return [] unless encoding_header = @partial_request.headers['transfer-encoding']
    
    encoding_header.split(", ").map do |encoding|
      encoding = encoding.downcase.to_sym
      raise ServerException::BadRequest.new("Unsupported transfer-encoding") unless SUPPORTED_ENCODINGS.include?(encoding)
      encoding
    end
  end

  def parse_regular_body(buffer)
    content_length = @partial_request.headers['content-length']&.to_i || 0
    return true if content_length == 0
    
    return false if buffer.bytesize < content_length
    
    @partial_request.body = buffer.slice!(0, content_length)
    true
  end

  def parse_chunked_body(buffer)
    body = ""
    
    loop do
      chunk_size_end = buffer.index("\r\n")
      return false unless chunk_size_end
      
      chunk_size = buffer[0...chunk_size_end].to_i(16)
      if chunk_size == 0
        return buffer.include?("\r\n\r\n")
      end
      
      buffer.slice!(0..chunk_size_end + 1)
      body << buffer.slice!(0...chunk_size)
      buffer.slice!(0..1)
    end
    
    @partial_request.body = body
    true
  end

  def decode_body(encodings)
    encodings.reverse.each do |encoding|
      @partial_request.body = case encoding
        when :compress
          Zlib::Inflate.new(Zlib::MAX_WBITS).inflate(@partial_request.body)
        when :deflate
          Zlib::Inflate.inflate(@partial_request.body)
        when :gzip
          gz = Zlib::GzipReader.new(StringIO.new(@partial_request.body))
          body = gz.read
          gz.close
          body
      end
    end
  end

  def validate_body(body, schema)
    return unless schema
    
    #TODO validate body against schema
  end

  def advance_buffer(buffer, delimiter)
    buffer.slice!(0..buffer.index(delimiter) + delimiter.length - 1)
  end

  def skip_request
    #TODO taglia il buffer, chiama reset_parser
end