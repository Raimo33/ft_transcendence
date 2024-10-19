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
