require 'jwt'
require 'net/http'
require 'uri'
require 'json'

class JwtValidator
  KEYCLOAK_DOMAIN = ENV['KEYCLOAK_DOMAIN']
  KEYCLOAK_REALM = ENV['KEYCLOAK_REALM']
  KEYCLOAK_CERTS = ENV['KEYCLOAK_CERTS']
  JWT_CACHE_EXPIRY = ENV['JWT_CACHE_EXPIRY'].to_i
  JWT_ALGORITHM = ENV['JWT_ALGORITHM']

  def initialize
    @public_key = nil
    @last_fetched = nil
  end

  def fetch_public_key
    return @public_key if @public_key && (Time.now - @last_fetched < JWT_CACHE_EXPIRY)

    uri = URI("#{KEYCLOAK_DOMAIN}#{KEYCLOAK_REALM}#{KEYCLOAK_CERTS}")
    response = Net::HTTP.get(uri)
    #TODO handle error (log)
    jwks = JSON.parse(response)

    #TODO abbellire
    return nil unless jwks['keys'] && jwks['keys'][0] && jwks['keys'][0]['x5c'] && jwks['keys'][0]['x5c'][0]

    @public_key = OpenSSL::X509::Certificate.new(Base64.decode64(jwks['keys'][0]['x5c'][0])).public_key
    @last_fetched = Time.now
    @public_key
  end

  def validate_token(token)
    decoded_token = _verify_token(token)
    return false unless decoded_token
    
    _validate_claims(decoded_token)
  end
  
  private

  def _verify_token(token)
    public_key = fetch_public_key
    decoded_token = JWT.decode(token, public_key, true, { algorithm: JWT_ALGORITHM })
    decoded_token
  rescue JWT::DecodeError => e
    #TODO log error
  end

  def _validate_claims(decoded_token)
    exp = decoded_token[0]['exp']
    iat = decoded_token[0]['iat']
    aud = decoded_token[0]['aud']

    return false if exp.nil? || iat.nil? || aud.nil?
    return false if Time.now.to_i > exp
    return false if Time.now.to_i < iat

    true
  end

end
