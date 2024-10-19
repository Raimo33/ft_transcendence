require 'jwt'
require 'net/http'
require 'uri'
require 'json'

class JwtValidator
  KEYCLOAK_URL = 'https://keycloak.example.com/auth/realms/your-realm'
  CACHE_EXPIRY = 3600 # 1 hour

  def initialize
    @public_key = nil
    @last_fetched = nil
  end

  def fetch_public_key
    return @public_key if @public_key && (Time.now - @last_fetched < CACHE_EXPIRY)

    uri = URI("#{KEYCLOAK_URL}/protocol/openid-connect/certs")
    response = Net::HTTP.get(uri)
    jwks = JSON.parse(response)
    @public_key = OpenSSL::X509::Certificate.new(Base64.decode64(jwks['keys'][0]['x5c'][0])).public_key
    @last_fetched = Time.now
    @public_key
  end

  def decode_token(token)
    JWT.decode(token, nil, false)
  end

  def verify_token(token)
    public_key = fetch_public_key
    decoded_token = JWT.decode(token, public_key, true, { algorithm: 'RS256' })
    decoded_token
  rescue JWT::DecodeError => e
    puts "Token verification failed: #{e.message}"
    nil
  end

  def validate_claims(decoded_token)
    exp = decoded_token[0]['exp']
    iat = decoded_token[0]['iat']
    aud = decoded_token[0]['aud']

    return false if exp.nil? || iat.nil? || aud.nil?
    return false if Time.now.to_i > exp
    return false if Time.now.to_i < iat

    true
  end

  def validate_token(token)
    decoded_token = verify_token(token)
    return false unless decoded_token

    validate_claims(decoded_token)
  end
end
