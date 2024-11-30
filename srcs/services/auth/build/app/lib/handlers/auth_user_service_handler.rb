# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_user_service_handler.rb                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/11/30 17:58:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require 'bcrypt'
require 'rotp'
require 'resolv'
require_relative '../config_handler'
require_relative '../grpc_server'

class AuthUserServiceHandler < AuthUser::Service
  include ServiceHandlerMiddleware

  def initialize
    @config = ConfigHandler.instance.config
    @private_key = OpenSSL::PKey::RSA.new(@config[:jwt][:private_key])
  end

  def ping(_request, _call)
    Google::Protobuf::Empty.new
  end

  def check_domain(request, _call)
    check_required_fields(request.domain)

    resolver   = Resolv::DNS.new
    mx_records = resolver.getresources(request.domain, Resolv::DNS::Resource::IN::MX)
    a_records  = resolver.getresources(request.domain, Resolv::DNS::Resource::IN::A)

    raise GRPC::BadRequest.new("Domain not found") if mx_records.empty? && a_records.empty?

    Google::Protobuf::Empty.new
  ensure
    resolver.close
  end

  def hash_password(request, _call)
    check_required_fields(request.password)

    hashed_password = BCrypt::Password.create(
      request.password,
      cost: @config.dig(:bcrypt, :cost)
    ).to_s

    AuthUser::HashedPassword.new(hashed_password)
  end

  def validate_password(request, _call)
    check_required_fields(request.password, request.hashed_password)

    password = BCrypt::Password.new(request.hashed_password)
    raise GRPC::InvalidArgument.new("Invalid password") unless password == request.password

    Google::Protobuf::Empty.new
  end

  def generate_tfa_secret(_request, _call)
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
      request.identifier,
      issuer: settings.fetch(:issuer, 'AuthService'),
      image:  settings.fetch(:image_url, nil)
    )

    AuthUser::Generate2FASecretResponse.new(
      tfa_secret:           secret,
      tfa_provisioning_uri: provisioning_uri
    )
  end

  def check_tfa_code(request, call)
    check_required_fields(request.secret, request.code)
    raise GRPC::InvalidArgument.new("Invalid secret format") unless ROTP::Base32.valid?(request.secret)

    settings = @config[:tfa]

    totp = ROTP::TOTP.new(
      request.secret,
      digits:        settings.fetch(:digits, 6),
      interval:      settings.fetch(:interval, 30),
      algorithm:     settings.fetch(:algorithm, 'SHA1'),
      issuer:        settings.fetch(:issuer, 'AuthService')
      drift_ahead:   settings.fetch(:drift_ahead, 1),
      drift_behind:  settings.fetch(:drift_behind, 1)
      verify_issuer: true
    )

    timestamp = totp.verify(
      request.code,
      drift_ahead:  settings.fetch(:drift_ahead, 1),
      drift_behind: settings.fetch(:drift_behind, 1)
      at:           Time.now.to_i
    )
    raise GRPC::InvalidArgument.new("Invalid code") if timestamp.nil?

    Google::Protobuf::Empty.new
  end

  def generate_jwt(request, _call)
    check_required_fields(request.user_id)

    settings = @config[:jwt]

    auth_level  = request.auth_level || 0
    expiry      = pending_tfa ? settings.fetch(:tfa_ttl, 300) : settings.fetch(:ttl, 3600)
    now         = Time.now.to_i

    payload = {
      iss:  'AuthService',
      sub:  request.user_id,
      iat:  now,
      exp:  now + expiry,
      jti:  SecureRandom.uuid,

      auth_level:  auth_level,
    }

    jwt = JWT.encode(
      payload,
      @private_key,
      settings.fetch(:algorithm, 'RS256')
    )

    AuthUser::JWT.new(jwt)
  end

  private

  def check_required_fields(*fields)
    raise GRPC::InvalidArgument.new("Missing required fields") unless fields.all?(&method(:provided?))
  end

  def provided?(field)
    field.respond_to?(:empty?) ? !field.empty? : !field.nil?
  end

end