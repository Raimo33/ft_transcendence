require 'jwt'
require 'net/http'
require 'uri'
require 'json'

class JwtValidator
  def initialize(config)
    @config = config
    @public_key = nil
    @last_fetched = nil
  end

  def fetch_public_key
    return @public_key if @public_key && (Time.now - @last_fetched < $JWT_PUB_KEY_TTL)

    uri = URI($JWT_PUB_KEY_URI)
    response = Net::HTTP.get(uri)
    jwks = JSON.parse(response)

    return nil unless jwks&.dig('keys', 0, 'x5c', 0)

    @public_key = OpenSSL::X509::Certificate.new(Base64.decode64(jwks['keys'][0]['x5c'][0])).public_key
    @last_fetched = Time.now
    @public_key

  end

  def validate_token(token)
    decoded_token = _decode_token(token)
    return false unless decoded_token && _validate_claims(decoded_token)

    true
  end
  
  private

  def _decode_token(token)
    public_key = fetch_public_key
    decoded_token = JWT.decode(token, public_key, true, { algorithm: $JWT_ALGORITHM })
    decoded_token

    nil
  end

  def _validate_claims(decoded_token)
    exp = decoded_token[0]['exp'] + JWT_EXPIRY_LEEWAY
    iat = decoded_token[0]['iat'] - JWT_EXPIRY_LEEWAY
    aud = decoded_token[0]['aud']

    return false unless exp && iat && aud
    now = Time.now.to_i
    return false unless (iat..exp).cover?(now)

    true
  end

end
