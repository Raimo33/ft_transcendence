# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_user_service_handler.rb                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/11/28 13:58:04 by craimond         ###   ########.fr        #
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
  end

  def ping(_request, _call)
    Google::Protobuf::Empty.new
  end

  def check_domain(request, _call)
    raise GRPC::InvalidArgument.new("Domain is required") if request.domain.empty?

    resolver   = Resolv::DNS.new
    mx_records = resolver.getresources(request.domain, Resolv::DNS::Resource::IN::MX)
    a_records  = resolver.getresources(request.domain, Resolv::DNS::Resource::IN::A)

    raise GRPC::BadRequest.new("Domain not found") if mx_records.empty? && a_records.empty?

    Google::Protobuf::Empty.new
  ensure
    resolver.close
  end

  def hash_password(request, _call)
    raise GRPC::InvalidArgument.new("Password is required") if request.password.empty?

    hashed_password = BCrypt::Password.create(
      request.password,
      cost: @config.dig(:bcrypt, :cost)
    ).to_s

    AuthUser::HashedPassword.new(hashed_password)
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
      secret:           secret,
      provisioning_uri: provisioning_uri
    )
  end

  def check_tfa_code(request, call)
    raise GRPC::InvalidArgument.new("Secret is required") if request.secret.empty?
    raise GRPC::InvalidArgument.new("Code is required") if request.code.empty?
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
    raise GRPC::InvalidArgument.new("User ID is required") if request.user_id.empty?

    settings = @config[:jwt]

    auth_level  = request.auth_level || 0
    pending_tfa = request.pending_tfa || false
    now         = Time.now.to_i

    payload = {
      iss:  settings.fetch(:issuer, 'AuthService'),
      sub:  request.user_id,
      iat:  now,
      exp:  #TODO dinamico in base a pending_tfa
      jti:  SecureRandom.uuid,

      user_id:     request.user_id,
      auth_level:  auth_level,
      pending_tfa: pending_tfa
    }
    jwt = JWT.encode(
      settings.fetch(:secret) #TODO capire cosa e'
      settings.fetch(:algorithm, 'HS256'),
      settings.fetch(:headers, {})
    )

    AuthUser::JWT.new(jwt)
  end

end