# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    helpers.rb                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:36 by craimond          #+#    #+#              #
#    Updated: 2024/10/21 18:20:39 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

def extract_headers(client)
  headers = {}
  
  client.each_line do |line|
    break if line.strip.empty?
    key, value = line.split(': ', 2)
    headers[key.strip.downcase] = value.strip if key && value
  end

  headers
end

def extract_body(client, headers)
  return nil unless headers['content-length']

  body = client.read(headers['content-length'].to_i)
  JSON.parse(body) if body
end

def check_auth_header(auth_header, jwt_validator, required_auth_level)
  return false unless auth_header&.start_with?('Bearer')
  token = auth_header.split(' ')[1]
  return false unless token && jwt_validator.validate_token(token, required_auth_level)
  true
end

def send_success(client, status_code, body)
  client.puts "HTTP/1.1 #{status_code}"
  client.puts "Content-Type: application/json"
  client.puts body.to_json if body
  client.close
end

def send_error(client, status_code)
  client.puts "HTTP/1.1 #{status_code}"
  client.close
end

def send_response(client, response)
  if #TODO calls send_success or send_error based on the response
  end
end

def send_callback(client, response)
  if #TODO calls send_success or send_error based on the response (adds POST and callback url)
  end
end
