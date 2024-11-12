# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    RequestParser.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/07 18:16:50 by craimond          #+#    #+#              #
#    Updated: 2024/11/12 12:11:31 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

module RequestParser

  def self.parse_request(buffer, endpoint_tree, config)
    request = Request.new

    header_end = buffer.index("\r\n\r\n")
    return nil unless header_end

    headers_part = buffer.slice!(0, header_end)
    body_start_index = header_end + 4

    request_line, header_lines = headers_part.split("\r\n", 2)
    request.http_method, full_path, _ = request_line.split(" ", 3)
    raise ActionFailedException::BadRequest unless request.method && full_path
    raise ActionFailedException::URITooLong if full_path.size > config[:max_uri_length]

    raw_path, raw_query = full_path.split("?", 2)
    raise ActionFailedException::BadRequest unless raw_path

    endpoint = endpoint_tree.find_endpoint(raw_path)
    raise ActionFailedException::NotFound unless endpoint
    
    resource = endpoint.resources[request.http_method]
    raise ActionFailedException::MethodNotAllowed unless resource

    expected_request = resource.expected_request
    request.headers = parse_headers(expected_request.allowed_headers, header_lines)
    content_length = request.headers["content-length"]&.to_i

    if resource.body_required
      raise ActionFailedException::LengthRequired unless content_length
      raise ActionFailedException::ContentTooLarge if content_length > config[:max_body_size]
    end

    total_request_size = body_start_index + content_length
    return nil if buffer.size < total_request_size

    raw_body = buffer.slice!(body_start_index, content_length) if content_length > 0

    request.path_params       = parse_path_params(expected_request.allowed_path_params, resource.path_template, raw_path)
    request.query_params      = parse_query_params(expected_request.allowed_query_params, raw_query)
    request.body              = parse_body(expected_request.body_schema, raw_body)
    request.resource          = resource

    request
  end

  private

  def parse_headers(allowed_headers, raw_headers)
    headers = {}
  
    received_headers = raw_headers.split("\n").each_with_object({}) do |line, hash|
      name, value = line.split(": ", 2)
      hash[name.to_sym] = value.strip if name && value
    end
  
    allowed_headers.each do |name, config|
      if config[:required] && !received_headers.key?(name)
        raise "Missing required header: #{name}"
      end

      next unless received_headers.key?(name)
      
      value = received_headers[name]
      schema = config[:schema]
  
      if schema[:type] == "array" && config[:explode]
        headers[name] = value.split(",").map(&:strip)
      elsif schema[:type] == "integer"
        headers[name] = Integer(value) rescue raise "Invalid integer for header: #{name}"
      elsif schema[:type] == "string"
        headers[name] = value
      else
        raise "Unsupported type for header: #{name}"
      end
    end

    extra_headers = received_headers.keys - allowed_headers.keys
    @logger.warn("Received unexpected headers: #{extra_headers.join(', ')}") unless extra_headers.empty?
  
    headers
  end

  def parse_path_params(allowed_path_params, path_template, raw_path)
    path_params = {}
    
    template_segments = path_template.split('/').reject(&:empty?)
    path_segments = raw_path.split('/').reject(&:empty?)

    raise "Path does not match expected template structure." unless template_segments.size == path_segments.size
  
    template_segments.each_with_index do |segment, index|

      if segment.start_with?('{') && segment.end_with?('}')
        param_name = segment[1..-2].to_sym

        config = allowed_path_params[param_name]
        raise "Unexpected path parameter: #{param_name}" unless config
  
        param_value = path_segments[index]
        if config[:required] && param_value.nil?
          raise "Missing required path parameter: #{param_name}"
        end

        next unless param_value

        schema = config[:schema]
        case schema[:type]
        when "array"
          path_params[param_name] = param_value.split(",").map(&:strip)
        when "integer"
          path_params[param_name] = Integer(param_value) rescue raise "Invalid integer for path parameter: #{param_name}"
        when "string"
          path_params[param_name] = param_value
        else
          raise "Unsupported type for path parameter: #{param_name}"
        end
      end
    end
  
    path_params
  end

  def parse_query_params(allowed_query_params, raw_query)
    params = {}
  
    received_query_params = raw_query.split("&").each_with_object({}) do |pair, hash|
      key, value = pair.split("=", 2)
      hash[key.to_sym] = value if key && value
    end

    allowed_query_params.each do |name, config|
      schema = config[:schema]

      if schema[:type] == "object" && config[:style] == "deepObject" && !config[:explode]
        object_params = {}
  
        received_query_params.each do |full_key, value|
          if full_key.to_s.start_with?("#{name}[")
            property_name = full_key.to_s.match(/\[(.*?)\]/)[1].to_sym
  
            if schema[:properties].key?(property_name)
              case schema[:properties][property_name][:type]
              when "integer"
                object_params[property_name] = Integer(value) rescue raise "Invalid integer for #{name}[#{property_name}]"
              when "string"
                object_params[property_name] = value
              else
                raise "Unsupported type for #{name}[#{property_name}]"
              end
            end
          end
        end
  
        params[name] = object_params unless object_params.empty?
  
      else
        if config[:required] && !received_query_params.key?(name)
          raise "Missing required query parameter: #{name}"
        end
  
        next unless received_query_params.key?(name)
  
        value = received_query_params[name]
        case schema[:type]
        when "array"
          params[name] = config[:explode] ? value.split(",").map(&:strip) : [value]
        when "integer"
          params[name] = Integer(value) rescue raise "Invalid integer for query parameter: #{name}"
        when "string"
          params[name] = value
        else
          raise "Unsupported type for query parameter: #{name}"
        end
      end
    end

    extra_params = received_query_params.keys - allowed_query_params.keys
    @logger.warn("Received unexpected query parameters: #{extra_params.join(', ')}") unless extra_params.empty?
  
    params
  end

  def parse_body(allowed_body, raw_body)
    result = {}
  
    begin
      received_body = JSON.parse(raw_body, symbolize_names: true)
    rescue JSON::ParserError
      raise "Invalid JSON in request body"
    end

    allowed_properties = allowed_body[:schema][:properties].keys
  
    extra_keys = received_body.keys - allowed_properties
    raise "Unexpected parameters in request body: #{extra_keys.join(', ')}" unless extra_keys.empty?
  
    allowed_properties.each do |name|
      config = allowed_body[:schema][:properties][name]
      schema = config[:schema]
  
      if config[:required] && !received_body.key?(name)
        raise "Missing required body parameter: #{name}"
      end
  
      next unless received_body.key?(name)
  
      value = received_body[name]
  
      case config[:type]
      when "object"
        if value.is_a?(Hash)
          nested_object = {}
          allowed_nested_keys = config[:properties].keys
          extra_nested_keys = value.keys - allowed_nested_keys
          raise "Unexpected parameters in #{name}: #{extra_nested_keys.join(', ')}" unless extra_nested_keys.empty?
  
          config[:properties].each do |nested_name, nested_config|
            if nested_config[:required] && !value.key?(nested_name)
              raise "Missing required field in #{name}: #{nested_name}"
            end
  
            nested_object[nested_name] = value[nested_name] if value.key?(nested_name)
          end
          result[name] = nested_object
        else
          raise "Invalid type for body parameter: #{name}, expected object"
        end
  
      when "array"
        if value.is_a?(Array)
          if config[:items]
            item_type = config[:items][:type]
            result[name] = value.map do |item|
              parse_value(item, item_type, name)
            end
          else
            result[name] = value
          end
        else
          raise "Invalid type for body parameter: #{name}, expected array"
        end
  
      when "string", "integer", "boolean"
        result[name] = parse_value(value, config[:type], name)
  
      else
        raise "Unsupported type for body parameter: #{name}"
      end
    end
  
    result
  end  
  
  def parse_value(value, type, param_name)
    case type
    when "integer"
      Integer(value) rescue raise "Invalid integer for body parameter: #{param_name}"
    when "string"
      value.is_a?(String) ? value : raise("Invalid string for body parameter: #{param_name}")
    when "boolean"
      return true if value == true || value.to_s.downcase == "true"
      return false if value == false || value.to_s.downcase == "false"
      raise "Invalid boolean for body parameter: #{param_name}"
    else
      raise "Unsupported type for body parameter: #{param_name}"
    end
  end

end