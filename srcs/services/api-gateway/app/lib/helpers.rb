# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    helpers.rb                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:36 by craimond          #+#    #+#              #
#    Updated: 2024/10/20 08:33:37 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

def extract_headers(client)
  headers = {}
  
  while (line = client.gets)
    break if line.strip.empty?
    key, value = line.split(': ', 2)
    headers[key.strip.downcase] = value.strip if key && value
  end

  headers
end

def check_auth_header(auth_header, jwt_validator, required_auth_level)
  return false unless auth_header&.start_with?('Bearer')
  token = auth_header.split(' ')[1]
  return false unless token && jwt_validator.validate_token_with_auth_level(token, required_auth_level)
  true
end

def return_error(client, status_code, message)
  client.puts "HTTP/1.1 #{status_code}\r\nContent-Type: application/json\r\n\r\n"
  client.puts({ error: message }.to_json)
  client.close
end
