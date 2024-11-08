# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    JwtValidator.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/01 19:14:39 by craimond          #+#    #+#              #
#    Updated: 2024/11/08 22:59:39 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'jwt'
require 'net/http'
require 'json'
require 'base64'
require 'openssl'
require_relative './modules/Logger'
require_relative './modules/ConfigLoader'

class JwtValidator
  include ConfigLoader
  include Logger

  def initialize(config)
    @config = config
    @logger = Logger.logger
    @public_key = nil
    @last_fetched = nil

    @http = Net::HTTP.new(@config[:jwt_jwks_uri].split('/')[2], 443)
    @http.use_ssl = true
    keycloak_cert = OpenSSL::X509::Certificate.new(File.read(@config[:keycloak_cert]))
    @http.ssl_context = OpenSSL::SSL::SSLContext.new
    @http.ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
    @http.ssl_context.cert_store = OpenSSL::X509::Store.new
    @http.ssl_context.cert_store.add_cert(keycloak_cert)

    @jwks_uri = URI(@config[:jwt_jwks_uri])
  end

  def token_valid?(token)
    decoded_token = decode_token(token)
    return false unless decoded_token

    validate_claims(decoded_token)
  end

  def token_authorized?(token, expected_auth_level)
    decoded_token = decode_token(token)
    return false unless decoded_token

    token_auth = decoded_token[0]['auth_level']
    return token_auth >= expected_auth_level
  end 

  def get_subject(token)
    decoded_token = decode_token(token)
    return false unless decoded_token

    decoded_token[0]['sub']
  end

  private

  def decode_token(token)
    public_key = fetch_public_key

    JWT.decode(token, public_key, true, { algorithm: @config[:jwt_algorithm] })
  rescue StandardError => e
    @logger.error("Failed to decode token: #{e}")
    nil
  end

  def fetch_public_key
    return @public_key if @public_key && (Time.now - @last_fetched < @config[:jwt_key_refresh_interval])
    @logger.debug('Fetching public key from JWKS endpoint')

    @logger.debug("Fetching JWKS from #{@jwks_uri}")
    response = @http.get(@jwks_uri)
    jwks = JSON.parse(response.body)

    return nil unless jwks&.dig('keys', 0, 'x5c', 0)

    @logger.debug('Parsing public key from JWKS')
    @public_key = OpenSSL::X509::Certificate.new(Base64.decode64(jwks['keys'][0]['x5c'][0])).public_key
    @last_fetched = Time.now
    @public_key
  rescue StandardError => e
    raise "Failed to fetch public key: #{e}"
  end

  def validate_claims(decoded_token)
    exp = decoded_token[0]['exp'] + @config[:jwt_clock_skew]
    iat = decoded_token[0]['iat'] - @config[:jwt_clock_skew]
    aud = decoded_token[0]['aud']

    return false unless exp && iat && aud
    now = Time.now.to_i
    return false unless (iat..exp).cover?(now)
    return false unless aud == @config[:jwt_audience]

    true
  end

end
