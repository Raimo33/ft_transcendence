require 'jwt'
require 'net/http'
require 'uri'
require 'json'

class JwtValidator
  def initialize
    @public_key = nil
    @last_fetched = nil
  end

  def fetch_public_key
    return @public_key if @public_key && (Time.now - @last_fetched < $JWT_CACHE_EXPIRY)

    uri = URI("#{$KEYCLOAK_HOST}#{$KEYCLOAK_REALM}#{$KEYCLOAK_CERTS}")
    response = Net::HTTP.get(uri)
    jwks = JSON.parse(response)

    return nil unless jwks&.dig('keys', 0, 'x5c', 0)

    @public_key = OpenSSL::X509::Certificate.new(Base64.decode64(jwks['keys'][0]['x5c'][0])).public_key
    @last_fetched = Time.now
    @public_key

  rescue Net::HTTPError => e
    STDERR.puts "Error fetching public key: #{e.message}"
  rescue JSON::ParserError => e
    STDERR.puts "Error parsing public key: #{e.message}"
  rescue StandardError => e
    STDERR.puts "Unexpected error: #{e.message}"
    nil
  end

  def validate_token(token)
    decoded_token = _verify_token(token)
    return false unless decoded_token

    _validate_claims(decoded_token)
  end

  def validate_token_with_auth_level(token, required_auth_level)
    decoded_token = _verify_token(token)
    return false unless decoded_token

    return false unless _validate_claims(decoded_token)
    return false unless _validate_auth_level(decoded_token, required_auth_level)

    true
  end
  
  private

  def _verify_token(token)
    public_key = fetch_public_key
    decoded_token = JWT.decode(token, public_key, true, { algorithm: $JWT_ALGORITHM })
    decoded_token

  rescue JWT::DecodeError => e
    STDERR.puts "Error decoding token: #{e.message}"
  rescue StandardError => e
    STDERR.puts "Unexpected error: #{e.message}"
    nil
  end

  def _validate_claims(decoded_token)
    exp = decoded_token[0]['exp']
    iat = decoded_token[0]['iat']
    aud = decoded_token[0]['aud']

    return false if exp.nil? || iat.nil? || aud.nil?
    return false if Time.now.to_i > exp + JWT_EXPIRY_LEEWAY
    return false if Time.now.to_i < iat - JWT_EXPIRY_LEEWAY

    true
  end

  def _validate_auth_level(decoded_token, required_auth_level)
    user_roles = decoded_token[0]['roles'] || []
    case required_auth_level
    when AuthLevel::ADMIN
      user_roles.include?('admin')
    when AuthLevel::USER
      user_roles.include?('user') || user_roles.include?('admin')
    else
      true
    end
  end

end
