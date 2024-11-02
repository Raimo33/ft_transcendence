# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    JwtValidator.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/01 19:14:39 by craimond          #+#    #+#              #
#    Updated: 2024/11/02 16:03:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'jwt'
require 'net/http'
require 'json'
require 'base64'
require 'openssl'
require_relative 'Logger'

class JwtValidator
  def initialize
    @logger = Logger.logger
    @public_key = nil
    @last_fetched = nil
  end

  def token_valid?(token)
    decoded_token = decode_token(token)
    return false unless decoded_token

    validate_claims(decoded_token)
  end

  def get_subject(token)
    decoded_token = decode_token(token)
    return false unless decoded_token

    decoded_token[0]['sub']
  end

  private

  def decode_token(token)
    public_key = fetch_public_key

    JWT.decode(token, public_key, true, { algorithm: $JWT_ALGORITHM })
  rescue StandardError => e
    @logger.error("Error decoding token: #{e.message}")
    @logger.debug(e.backtrace.join("\n"))
    nil
  end

  def fetch_public_key
    return @public_key if @public_key && (Time.now - @last_fetched < $JWT_PUB_KEY_TTL)
    @logger.debug('Fetching public key from JWKS endpoint')

    uri = URI($JWT_PUB_KEY_URI)
    @logger.debug("Fetching JWKS from #{uri}")
    response = Net::HTTP.get(uri)
    jwks = JSON.parse(response)

    return nil unless jwks&.dig('keys', 0, 'x5c', 0)

    @logger.debug('Parsing public key from JWKS')
    @public_key = OpenSSL::X509::Certificate.new(Base64.decode64(jwks['keys'][0]['x5c'][0])).public_key
    @last_fetched = Time.now
    @public_key
  rescue StandardError => e
    raise "Error fetching public key: #{e}"
  end


  def validate_claims(decoded_token)
    exp = decoded_token[0]['exp'] + JWT_EXPIRY_LEEWAY
    iat = decoded_token[0]['iat'] - JWT_EXPIRY_LEEWAY
    aud = decoded_token[0]['aud']

    return false unless exp && iat && aud
    now = Time.now.to_i
    return false unless (iat..exp).cover?(now)
    return false unless aud == $JWT_AUDIENCE

    true
  end

end
