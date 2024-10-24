# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    helpers.rb                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:36 by craimond          #+#    #+#              #
#    Updated: 2024/10/24 10:53:54 by craimond         ###   ########.fr        #
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

def check_auth_header(auth_header, jwt_validator)
  return false unless auth_header&.start_with?('Bearer')
  token = auth_header.split(' ')[1]
  return false unless token && jwt_validator.validate_token(token)
  true
end
