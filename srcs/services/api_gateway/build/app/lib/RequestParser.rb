# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    RequestParser.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/20 06:06:29 by craimond          #+#    #+#              #
#    Updated: 2024/11/23 11:59:28 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative "modules/Structs"
require 'zlib'
require 'stringio'

class RequestParser
  STATES = %i[FIRST_LINE HEADERS BODY COMPLETE].freeze
  RECOGNISED_METHODS = %i[GET POST PUT PATCH DELETE].freeze
  SUPPORTED_ENCODINGS = %i[compress deflate gzip identity].freeze

  def initialize(endpoint_tree)
    @config = ConfigurableLogger.instance.config
    @logger = ConfigurableLogger.instance.logger
    @state = STATES.first
    @partial_request = Request.new
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

    decode_body(transfer_encodings)
    @state = :COMPLETE
    nil
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

  def advance_buffer(buffer, delimiter)
    buffer.slice!(0..buffer.index(delimiter) + delimiter.length - 1)
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
    raw_path, raw_query = raw_path.split("?")
    raise ServerException::BadRequest.new("Invalid path") unless raw_path
    @partial_request.path = raw_path
    @partial_request.query_params = 


    @partial_request.version = words[2]
    raise ServerException::BadRequest.new("Missing version") unless @partial_request.version == "HTTP/1.1"
  end

  def parse_headers(buffer)
    headers_block = buffer.split("\r\n\r\n").first
    raise ServerException::BadRequest.new("Missing headers") unless headers_block

    headers = headers_block.split("\r\n")
    headers.each do |header|
      key, value = header.split(": ")
      @partial_request.headers[key.downcase.to_sym] = value
    end
  end

  private

  def skip_request
    #TODO taglia il buffer, chiama reset_parser
end