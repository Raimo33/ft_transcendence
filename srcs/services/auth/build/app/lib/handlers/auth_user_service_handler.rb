# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_user_service_handler.rb                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 18:49:40 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require 'bcrypt'
require 'rotp'
require 'resolv'
require_relative '../config_handler'
require_relative '../grpc_server'

class AuthUserServiceHandler < AuthUser::Service

  def initialize
    @config = ConfigHandler.instance.config
    @private_key = OpenSSL::PKey::RSA.new(@config[:jwt][:private_key])
  end

  def ping(_request, call)
    Empty.new
  end

  def check_domain(request, call)
    check_required_fields(request.domain)

    resolver   = Resolv::DNS.new
    mx_records = resolver.getresources(request.domain, Resolv::DNS::Resource::IN::MX)
    a_records  = resolver.getresources(request.domain, Resolv::DNS::Resource::IN::A)

    raise GRPC::InvalidArgument.new("Invalid domain") if mx_records.empty? && a_records.empty?

    Empty.new
  ensure
    resolver.close
  end

  def hash_password(request, call)
    check_required_fields(request.password)

    hashed_password = BCrypt::Password.create(
      request.password,
      cost: @config.dig(:bcrypt, :cost)
    )

    AuthUser::HashedPassword.new(hashed_password)
  end

  def validate_password(request, call)
    check_required_fields(request.password, request.hashed_password)

    password = BCrypt::Password.new(request.hashed_password)
    raise GRPC::InvalidArgument.new("Invalid password") unless password == request.password

    Empty.new
  end

  def generate_tfa_secret(request, call)
    check_required_fields(request.id)

    settings = @config[:tfa]

    secret = ROTP::Base32.random(32)
    totp = ROTP::TOTP.new(
      secret,
      digits:        settings.fetch(:digits, 6),
      interval:      settings.fetch(:interval, 30),
      algorithm:     settings.fetch(:algorithm, 'SHA1'),
      issuer:        settings.fetch(:issuer, 'AuthService')
      drift_ahead:   settings.fetch(:drift_ahead, 1),
      drift_behind:  settings.fetch(:drift_behind, 1)
      verify_issuer: true
    )
  
    provisioning_uri = totp.provisioning_uri(
      request.id,
      issuer: settings.fetch(:issuer, 'AuthService'),
      image:  settings.fetch(:image_url, nil)
    )

    AuthUser::Generate2FASecretResponse.new(
      tfa_secret:           secret,
      tfa_provisioning_uri: provisioning_uri
    )
  end

  def check_tfa_code(request, call)
    check_required_fields(request.tfa_secret, request.tfa_code)
    raise GRPC::InvalidArgument.new("Invalid secret format") unless ROTP::Base32.valid?(request.tfa_secret)

    settings = @config[:tfa]

    totp = ROTP::TOTP.new(
      request.tfa_secret,
      digits:        settings.fetch(:digits, 6),
      interval:      settings.fetch(:interval, 30),
      algorithm:     settings.fetch(:algorithm, 'SHA1'),
      issuer:        settings.fetch(:issuer, 'AuthService')
      drift_ahead:   settings.fetch(:drift_ahead, 1),
      drift_behind:  settings.fetch(:drift_behind, 1)
      verify_issuer: true
    )

    timestamp = totp.verify(
      request.tfa_code,
      drift_ahead:  settings.fetch(:drift_ahead, 1),
      drift_behind: settings.fetch(:drift_behind, 1)
      at:           Time.now.to_i
    )
    raise GRPC::InvalidArgument.new("Invalid code") if timestamp.nil?

    Empty.new
  end

  def generate_jwt(request, call)
    check_required_fields(request.identifier, request.ttl)

    settings = @config[:jwt]

    now = Time.now.to_i
    standard_claims = {
      iss:  settings.fetch(:issuer, 'AuthService'),
      sub:  request.identifier,
      iat:  now,
      exp:  now + request.ttl,
      jti:  SecureRandom.uuid,
    }

    payload = standard_claims.merge(request.custom_claims&.to_h)

    jwt = JWT.encode(
      payload,
      @private_key,
      settings.fetch(:algorithm, 'RS256')
    )

    AuthUser::JWT.new(jwt)
  end

  def decode_jwt(request, call)
    check_required_fields(request.jwt)

    settings = @config[:jwt]

    payload, headers = JWT.decode(
      request.jwt,
      @private_key.public_key,
      true,
      {
        algorithm:  settings.fetch(:algorithm, 'RS256'),
        verify_iss: true,
        verify_aud: true,
        iss:        settings.fetch(:issuer, 'AuthService'),
        aud:        settings.fetch(:audience, nil)
      }
    ).first

    AuthUser::DecodedJWT.new(
      payload: Google::Protobuf::Struct.from_hash(payload),
      headers: Google::Protobuf::Struct.from_hash(headers)
    )
  end

  def clone_jwt(request, call)
    check_required_fields(request.jwt)

    settings = @config[:jwt]

    payload, _headers = JWT.decode(
      request.jwt,
      @private_key.public_key,
      false,
    )

    now = Time.now.to_i
    original_ttl = payload['exp'] - payload['iat']
    payload = payload.transform_keys(&:to_sym).except(:exp, :iat, :jti).merge(
      iat: now,
      exp: now + original_ttl,
      jti: SecureRandom.uuid
    )

    new_jwt = JWT.encode(
      payload,
      @private_key,
      settings.fetch(:algorithm, 'RS256')
    )

    AuthUser::JWT.new(new_jwt)
  end

  private

  def check_required_fields(*fields)
    raise GRPC::InvalidArgument.new("Missing required fields") unless fields.all?(&method(:provided?))
  end

  def provided?(field)
    field.respond_to?(:empty?) ? !field.empty? : !field.nil?
  end

end