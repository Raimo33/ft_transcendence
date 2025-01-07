require 'singleton'
require 'jwt'
require_relative '../shared/config_handler'
require_relative '../shared/exceptions'

class AuthModule
  include Singleton

  def check_authorization(auth_header)
    session_token = auth_header&.split("Bearer ")&.last
    raise Unauthorized.new("Unauthorized") unless session_token
    
    payload, _ = JWT.decode(
      session_token,
      @jwt_public_key,
      true,
      { algorithm: @config.dig(:jwt, :algorithm) }
    )
    payload["sub"]
  rescue JWT::DecodeError
    raise Unauthorized.new("Unauthorized")
  end

  def load_public_key(public_key_path)
    public_key = File.read(public_key_path)
    OpenSSL::PKey::RSA.new(public_key)
  end
end