# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    RequestParser.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/18 18:42:10 by craimond          #+#    #+#              #
#    Updated: 2024/11/18 19:28:12 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative "modules/Structs"

class RequestParser

  RECOGNISED_METHODS = [:GET, :POST, :PUT, :PATCH, :DELETE].freeze

  def initialize(endpoint_tree)
    @config        = ConfigLoader.instance.config
    @logger        = ConfigurableLogger.instance.logger
    @endpoint_tree = endpoint_tree
  end

  def parse_request(buffer)
    request = Request.new

    first_line = buffer.split("\r\n").first
    return ServerException::BadRequest.new("Invalid request") unless first_line

    raw_method, raw_full_path, _ = first_line.split

    request.http_method  = raw_method.upcase.to_sym
    raise ServerException::MethodNotAllowed.new("Invalid HTTP method: #{request.http_method}") unless RECOGNISED_METHODS.include?(request.http_method)
  
    raw_path, raw_query = raw_full_path.split('?')

    request.path         = get_corresponding_path(raw_path)
    request.path_params  = parse_path_params(raw_path)
    request.query_params = parse_query_params(raw_query)

    raw_headers, raw_body = buffer.split("\r\n\r\n")

    request.headers   = parse_headers(raw_headers)
    request.body      = parse_body(raw_body)


    #TODO return in caso di fine del buffer
    #TODO slicing del buffer
  end

  private

  def parse_http_method(first_line)
    return nil if first_line.nil? || first_line.empty?

    words = first_line.split
    return nil unless words.size == 3

    method = words[0].upcase
    return ServerException::MethodNotAllowed.new("Invalid HTTP method: #{method}") unless RECOGNISED_METHODS.include?(method.to_sym)

    method
  end

  def parse_path_params(buffer)
    return nil if buffer.nil? || buffer.empty?

    first_line = buffer.split("\r\n").first
    return nil unless first_line

    words = first_line.split
    return nil unless words.size == 3

    path = words[1]
    return nil if path.nil? || path.empty?

    path
  end

  def get_corresponding_path(raw_path)
    node = @endpoint_tree.find_endpoint(raw_path)
    return nil unless node

    node.content.keys.first
  end

  #TODO altri metodi che fanno esclusivamente parsing, non checks rispetto a expected request
