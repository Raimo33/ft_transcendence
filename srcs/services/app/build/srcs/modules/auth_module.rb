# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_module.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/03 12:07:04 by craimond          #+#    #+#              #
#    Updated: 2025/01/04 17:02:26 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'jwt'
require 'singleton'
require 'resolv'
require_relative '../shared/config_handler'
require_relative '../shared/memcached_client'
require_relative '../shared/exceptions'

class AuthModule
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config.fetch(:auth)
    @private_key = OpenSSL::PKey::RSA.new(File.read(@config..dig(:jwt, :private_key)))
    @memcached_client = MemcachedClient.instance
  end

  def validate_jwt(jwt)
    settings = @config.fetch(:jwt)

    payload, headers = JWT.decode(
      request.jwt,
      @private_key.public_key,
      true,
      {
        algorithm: settings.fetch(:algorithm),
        required_claims: %w[sub iat exp iss aud jti],
        verify_exp: true,
        verify_iat: true,
        verify_iss: true,
        verify_aud: true,
        iss: settings.fetch(:issuer),
        aud: settings.fetch(:audience)
        iat: Time.now.to_i,
        leeway: settings.fetch(:leeway)
      }
    )
    raise Unauthorized.new("Token revoked") if token_revoked?(payload["sub"], payload["iat"])
    
    payload
  rescue JWT::DecodeError
    raise Unauthorized.new("Invalid token")
  end

  def check_domain(domain)
    resolver   = Resolv::DNS.new
    mx_records = resolver.getresources(domain, Resolv::DNS::Resource::IN::MX)
    a_records  = resolver.getresources(domain, Resolv::DNS::Resource::IN::A)

    raise BadRequest.new("Invalid domain") if mx_records.empty? && a_records.empty?
  rescue Resolv::ResolvError
    raise BadRequest.new("Invalid domain")
  ensure
    resolver.close
  end

  def hash_password(password)
    BCrypt::Password.create(password, cost: @config.dig(:bcrypt, :cost))
  rescue BCrypt::Error
    raise InternalServerError.new("Error hashing password")
  end

  def validate_password(provided_password, hashed_password)
    actual_password = BCrypt::Password.new(hashed_password)
    raise Unauthorized.new("Invalid password") unless actual_password == provided_password
  rescue BCrypt::Error
    raise InternalServerError.new("Error validating password")
  end

  def generate_tfa_secret(identifier)
    settings = @config.fetch(:tfa)

    secret = ROTP::Base32.random(32)
    totp = ROTP::TOTP.new(
      secret,
      digits:        settings.fetch(:digits),
      interval:      settings.fetch(:interval),
      algorithm:     settings.fetch(:algorithm),
      issuer:        settings.fetch(:issuer),
      drift_ahead:   settings.fetch(:drift_ahead),
      drift_behind:  settings.fetch(:drift_behind),
      verify_issuer: true
    )
  
    provisioning_uri = totp.provisioning_uri(
      identifier,
      issuer: settings.fetch(:issuer),
      image:  settings.fetch(:image_url)
    )

    [secret, provisioning_uri]
  rescue ROTP::Error
    raise InternalServerError.new("Error generating TFA secret")
  end

  def check_tfa_code(tfa_secret, tfa_code)
    raise BadRequest.new("Invalid secret format") unless ROTP::Base32.valid?(request.tfa_secret)

    settings = @config.fetch(:tfa)

    totp = ROTP::TOTP.new(
      tfa_secret,
      digits:        settings.fetch(:digits),
      interval:      settings.fetch(:interval),
      algorithm:     settings.fetch(:algorithm),
      issuer:        settings.fetch(:issuer),
      drift_ahead:   settings.fetch(:drift_ahead),
      drift_behind:  settings.fetch(:drift_behind),
      verify_issuer: true
    )

    timestamp = totp.verify(
      tfa_code,
      drift_ahead:  settings.fetch(:drift_ahead),
      drift_behind: settings.fetch(:drift_behind),
      at:           Time.now.to_i,
    )
    raise Unauthorized.new("Invalid TFA code") if timestamp.nil?
  rescue ROTP::Error
    raise Unauthorized.new("Error validating TFA code")
  end

  def generate_jwt(identifier, ttl, custom_claims = nil)
    settings = @config.fetch(:jwt)

    now = Time.now.to_i
    standard_claims = {
      iss:  settings.fetch(:issuer),
      sub:  identifier,
      iat:  now,
      exp:  now + ttl,
      jti:  SecureRandom.uuid,
    }

    payload = standard_claims.merge(custom_claims&.to_h)

    JWT.encode(payload, @private_key, settings.fetch(:algorithm))
  rescue JWT::EncodeError
    raise InternalServerError.new("Error generating JWT")
  end

  def extend_jwt(jwt)
    settings = @config.fetch(:jwt)

    payload, _headers = JWT.decode(request.jwt, @private_key.public_key, false)
    payload.transform_keys(&:to_sym)

    now = Time.now.to_i
    original_ttl = payload["exp"] - payload["iat"]
    payload = payload.except(:exp, :iat, :jti).merge(
      iat: now,
      exp: now + original_ttl,
      jti: SecureRandom.uuid
    )

    JWT.encode(payload, @private_key, settings.fetch(:algorithm))
  rescue JWT::DecodeError
    raise Unauthorized.new("Invalid token")
  rescue JWT::EncodeError
    raise InternalServerError.new("Error extending JWT")
  end

  private

  def token_revoked?(sub, iat)
    token_invalid_before = @memcached_client.get("token_invalid_before:#{sub}")
    return true if token_invalid_before.nil?

    iat < token_invalid_before.to_i
  end

end