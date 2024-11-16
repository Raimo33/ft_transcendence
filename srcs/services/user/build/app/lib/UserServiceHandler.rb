# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    UserAPIGatewayServiceHandler.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 20:01:35 by craimond          #+#    #+#              #
#    Updated: 2024/11/12 12:37:40 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require "pg"
require "pg_pool"
require "base64"
require "mini_magick"
require "async"
require "email_validator"
require_relative "ConfigLoader"
require_relative "ConfigurableLogger"
require_relative "../proto/user_pb"
require_relative "../proto/auth_user_pb"

class UserAPIGatewayServiceHandler < UserAPIGatewayService::Service
  include EmailValidator

  def initialize(grpc_client)
    @grpc_client = grpc_client
    @logger = ConfigurableLogger.instance.logger
    @config = ConfigLoader.config

    @db_pool = PG::Pool.new(
      dbname:           @config[:database][:name],
      user:             @config[:database][:user],
      password:         @config[:database][:password],
      host:             @config[:database][:host],
      port:             @config[:database][:port]
      max_connections:  @config[:database][:max_connections]
      check_interval:   @config[:database][:check_interval]
    )
                          
    @default_avatar = load_default_avatar
  end

  def register_user(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.email, request.password, request.display_name]
    unless required_fields.all?(&:present?)
      @logger.error("Missing required fields")
      return UserAPIGatewayService::RegisterUserResponse.new(status_code: 400)
    end

    barrier = Async::Barrier.new

    barrier.async do |task|
      task.async { check_email(request.email) }
      task.async { check_password(request.password) }
      task.async { check_display_name(request.display_name) }
      task.async { check_avatar(request.avatar) } if request.avatar
    rescue StandardError => e
      @logger.error("Failed to register user: #{e}")
      return UserAPIGatewayService::RegisterUserResponse.new(status_code: 400)
    end
    barrier.wait

    barrier.async do |task|
      email            = request.email
      display_name     = request.display_name
      hashed_password  = task.async { hash_password(request.password) }
      avatar           = task.async { compress_avatar(request.avatar) } if request.avatar
    end
    barrier.wait

    @db_pool.with_connection do |conn|
      @logger.debug("Preparing statement")
      conn.prepare("register_user", "INSERT INTO Users (email, psw, display_name, avatar) VALUES ($1, $2, $3, $4) RETURNING id")
  
      @logger.debug("Registering user in database")
      db_response = conn.exec_prepared("register_user", [email, hashed_password, display_name, avatar])
  
      user_id = db_response.getvalue(0, 0)
      @logger.info("User with email '#{email}' registered successfully")
      return UserService::RegisterUserResponse.new(status_code: 201, user_id: user_id)
    end
  rescue PG::UniqueViolation => e
    @logger.error("Unique constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 409)
  rescue PG::CheckViolation => e
    @logger.error("Check constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::NotNullViolation => e
    @logger.error("Not null constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::ForeignKeyViolation => e
    @logger.error("Foreign key constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::Timeout => e
    @logger.error("Database connection timed out: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 504)
  rescue StandardError => e
    @logger.error("Failed to register user: #{e}")
    UserService::RegisterUserResponse.new(status_code: 500)
  ensure
    barrier.stop
  end

  def get_user_profile(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id, request.user_id]

    unless required_fields.all?(&:present?)
      @logger.error("Missing required fields")
      return UserService::GetUserProfileResponse.new(status_code: 400)
    end
  
    @db_pool.with_connection do |conn|
      @logger.debug("Preparing statement")
      conn.prepare("get_user_profile", "SELECT * FROM UserProfiles WHERE user_id = $1")

      @logger.debug("Querying database for user profile")
      db_response = conn.exec_prepared("get_user_profile", [request.user_id])

      if db_response.ntuples.zero?
        @logger.error("User profile for user with id '#{request.user_id}' not found")
        return UserService::GetUserProfileResponse.new(status_code: 404)
      end

      user_profile = UserService::UserProfile.new(
        user_id:      db_response.getvalue(0, 0),
        display_name: db_response.getvalue(0, 1),
        avatar:       db_response.getvalue(0, 2) || @default_avatar,
        status:       db_response.getvalue(0, 3)
      )

      @logger.info("User profile for user with id '#{request.user_id}' retrieved successfully")
      return UserService::GetUserProfileResponse.new(status_code: 200, profile: user_profile)
    end
  rescue PG::UniqueViolation => e
    @logger.error("Unique constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 409)
  rescue PG::CheckViolation => e
    @logger.error("Check constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::NotNullViolation => e
    @logger.error("Not null constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::ForeignKeyViolation => e
    @logger.error("Foreign key constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::Timeout => e
    @logger.error("Database connection timed out: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 504)
  rescue StandardError => e
    @logger.error("Failed to get user profile: #{e}")
    UserService::GetUserProfileResponse.new(status_code: 500)
  end

  def delete_account(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    unless required_fields.all?(&:present?)
      @logger.error("Missing required fields")
      return UserService::DeleteAccountResponse.new(status_code: 400)
    end

    @db_pool.with_connection do |conn|
      @logger.debug("Preparing statement")
      conn.prepare("delete_account", "DELETE FROM Users WHERE id = $1")
  
      @logger.debug("Deleting account from database")
      db_response = conn.exec_prepared("delete_account", [request.requester_user_id])
  
      if db_response.cmd_tuples.zero?
        @logger.error("User with id '#{request.requester_user_id}' not found")
        return UserService::DeleteAccountResponse.new(status_code: 404)
      end
  
      UserService::DeleteAccountResponse.new(status_code: 204)
    end
  rescue PG::UniqueViolation => e
    @logger.error("Unique constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 409)
  rescue PG::CheckViolation => e
    @logger.error("Check constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::NotNullViolation => e
    @logger.error("Not null constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::ForeignKeyViolation => e
    @logger.error("Foreign key constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::Timeout => e
    @logger.error("Database connection timed out: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 504)
  rescue StandardError => e
    @logger.error("Failed to delete account: #{e}")
    UserService::DeleteAccountResponse.new(status_code: 500)
  end

  def get_private_profile(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    unless required_fields.all?(&:present?)
      @logger.error("Missing required fields")
      return UserService::GetPrivateProfileResponse.new(status_code: 400)
    end

    @db_pool.with_connection do |conn|
      @logger.debug("Preparing statement")
      conn.prepare("get_private_profile", "SELECT * FROM UserPrivateProfiles WHERE id = $1")
  
      @logger.debug("Querying database for private profile")
      db_response = conn.exec_prepared("get_private_profile", [request.requester_user_id])
  
      if db_response.ntuples.zero?
        @logger.error("Private profile for user with id '#{request.requester_user_id}' not found")
        return UserService::GetPrivateProfileResponse.new(status_code: 404)
      end
  
      private_profile = UserService::User.new(
        id:                       db_response.getvalue(0, 0),
        email:                    db_response.getvalue(0, 1),
        display_name:             db_response.getvalue(0, 2),
        avatar:                   db_response.getvalue(0, 3) || @default_avatar,
        two_factor_auth_enabled:  db_response.getvalue(0, 4),
        status:                   db_response.getvalue(0, 5)
      )
  
      @logger.info("Private profile for user with id '#{request.requester_user_id}' retrieved successfully")
      return UserService::GetPrivateProfileResponse.new(status_code: 200, profile: private_profile)
    end
  rescue PG::UniqueViolation => e
    @logger.error("Unique constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 409)
  rescue PG::CheckViolation => e
    @logger.error("Check constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::NotNullViolation => e
    @logger.error("Not null constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::ForeignKeyViolation => e
    @logger.error("Foreign key constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::Timeout => e
    @logger.error("Database connection timed out: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 504)
  rescue StandardError => e
    @logger.error("Failed to get private profile: #{e}")
    UserService::GetPrivateProfileResponse.new(status_code: 500)
  end

  def update_profile(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    unless required_fields.all?(&:present?)
      @logger.error("Missing required fields")
      return UserService::UpdateProfileResponse.new(status_code: 400)
    end

    barrier = Async::Barrier.new

    barrier.async do |task|
      task.async { check_display_name(request.display_name) } if request.display_name
      task.async { check_avatar(request.avatar) } if request.avatar
    rescue StandardError => e
      @logger.error("Failed to update profile: #{e}")
      return UserService::UpdateProfileResponse.new(status_code: 400)
    end
    barrier.wait

    @db_pool.with_connection do |conn|
      @logger.debug("Preparing statements")
      conn.prepare("update_display_name", "UPDATE UserProfiles SET display_name = $1 WHERE user_id = $2")
      conn.prepare("update_avatar", "UPDATE UserProfiles SET avatar = $1 WHERE user_id = $2")
  
      dn_response, avatar_response = nil
      conn.transaction do
        Async do |task|
          dn_response = task.async do
            conn.exec_prepared("update_display_name", [request.display_name, request.requester_user_id]) if request.display_name
          end
  
          avatar_response = task.async do
            conn.exec_prepared("update_avatar", [compress_avatar(request.avatar), request.requester_user_id]) if request.avatar
          end
        end
        dn_response.wait
        avatar_response.wait
      end
  
      if dn_response&.cmd_tuples.zero? || avatar_response&.cmd_tuples.zero?
        @logger.error("User with id '#{request.requester_user_id}' not found")
        return UserService::UpdateProfileResponse.new(status_code: 404)
      end
  
      @logger.info("Profile for user with id '#{request.requester_user_id}' updated successfully")
      return UserService::UpdateProfileResponse.new(status_code: 204)
    end
  rescue PG::UniqueViolation => e
    @logger.error("Unique constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 409)
  rescue PG::CheckViolation => e
    @logger.error("Check constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::NotNullViolation => e
    @logger.error("Not null constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::ForeignKeyViolation => e
    @logger.error("Foreign key constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::Timeout => e
    @logger.error("Database connection timed out: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 504)
  rescue StandardError => e
    @logger.error("Failed to update profile: #{e}")
    UserService::UpdateProfileResponse.new(status_code: 500)
  ensure
    barrier.stop
  end

  def enable_2fa(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    unless required_fields.all?(&:present?)
      @logger.error("Missing required fields")
      return UserService::Enable2FAResponse.new(status_code: 400)
    end
  
    grpc_request  = AuthUserService::Generate2FASecretRequest.new
    @logger.debug("Sending 'Generate2FASecret' request to Auth service: #{grpc_request.inspect}")
    grpc_response = @grpc_client.auth.generate_2fa_secret(grpc_request)

    totp_secret = grpc_response&.totp_secret
    raise "AuthService failed to enable 2FA" unless totp_secret

    #TODO add totp_secret to UserPrivateProfiles table and set two_factor_auth_enabled to true
    
    @logger.info("2FA enabled successfully for user with id '#{request.requester_user_id}'")
    UserService::Enable2FAResponse.new(status_code: 200, totp_secret: totp_secret)
  rescue PG::UniqueViolation => e
    @logger.error("Unique constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 409)
  rescue PG::CheckViolation => e
    @logger.error("Check constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::NotNullViolation => e
    @logger.error("Not null constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::ForeignKeyViolation => e
    @logger.error("Foreign key constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::Timeout => e
    @logger.error("Database connection timed out: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 504)
  rescue StandardError => e
    @logger.error("Failed to enable 2FA: #{e}")
    UserService::Enable2FAResponse.new(status_code: 500)
  end

  def get_2fa_status(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    unless required_fields.all?(&:present?)
      @logger.error("Missing required fields")
      return UserService::Get2FAStatusResponse.new(status_code: 400)
    end

    @db_pool.with_connection do |conn|
      @logger.debug("Preparing statement")
      conn.prepare("get_2fa_status", "SELECT two_factor_auth_enabled FROM UserPrivateProfiles WHERE id = $1")
      @logger.debug("Querying database for 2FA status")
      db_response = conn.exec_prepared("get_2fa_status", [request.requester_user_id])
  
      if db_response.ntuples.zero?
        @logger.error("2FA status for user with id '#{request.requester_user_id}' not found")
        return UserService::Get2FAStatusResponse.new(status_code: 404)
      end
  
      two_factor_auth_enabled = db_response.getvalue(0, 0)
  
      @logger.info("2FA status for user with id '#{request.requester_user_id}' retrieved successfully")
      return UserService::Get2FAStatusResponse.new(status_code: 200, two_factor_auth_enabled: two_factor_auth_enabled)
    end
  rescue PG::UniqueViolation => e
    @logger.error("Unique constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 409)
  rescue PG::CheckViolation => e
    @logger.error("Check constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::NotNullViolation => e
    @logger.error("Not null constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::ForeignKeyViolation => e
    @logger.error("Foreign key constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::Timeout => e
    @logger.error("Database connection timed out: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 504)
  rescue StandardError => e
    @logger.error("Failed to get 2FA status: #{e}")
    UserService::Get2FAStatusResponse.new(status_code: 500)
  end

  def disable_2fa(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    unless required_fields.all?(&:present?)
      @logger.error("Missing required fields")
      return UserService::Disable2FAResponse.new(status_code: 400)
    end

    #TODO remove totp_secret from UserPrivateProfiles table and set two_factor_auth_enabled to false

    @logger.info("2FA disabled successfully for user with id '#{request.requester_user_id}'")
    UserService::Disable2FAResponse.new(status_code: 204)
  rescue PG::UniqueViolation => e
    @logger.error("Unique constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 409)
  rescue PG::CheckViolation => e
    @logger.error("Check constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::NotNullViolation => e
    @logger.error("Not null constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::ForeignKeyViolation => e
    @logger.error("Foreign key constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::Timeout => e
    @logger.error("Database connection timed out: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 504)
  rescue StandardError => e
    @logger.error("Failed to disable 2FA: #{e}")
    UserService::Disable2FAResponse.new(status_code: 500)
  end

  def check_2fa_code(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id, request.totp_code]
    unless required_fields.all?(&:present?)
      @logger.error("Missing required fields")
      return UserService::Check2FACodeResponse.new(status_code: 400)
    end

    #TODO retrieve totp_secret from UserPrivateProfiles table

    grpc_request = AuthUserService::Check2FACodeRequest.new(totp_secret: totp_secret, totp_code: request.totp_code)
    @logger.debug("Sending 'Check2FACode' request to Auth service: #{grpc_request.inspect}")
    grpc_response = @grpc_client.auth.check_2fa_code(grpc_request)
    raise "AuthService failed to check 2FA code" unless grpc_response

    is_valid = grpc_response&.is_valid

    @logger.info("2FA code for user with id '#{request.requester_user_id}' checked successfully")
    is_valid ? UserService::Check2FACodeResponse.new(status_code: 204) : UserService::Check2FACodeResponse.new(status_code: 401)
  rescue PG::UniqueViolation => e
    @logger.error("Unique constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 409)
  rescue PG::CheckViolation => e
    @logger.error("Check constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::NotNullViolation => e
    @logger.error("Not null constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::ForeignKeyViolation => e
    @logger.error("Foreign key constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::Timeout => e
    @logger.error("Database connection timed out: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 504)
  rescue StandardError => e
    @logger.error("Failed to check 2FA code: #{e}")
    UserService::Check2FACodeResponse.new(status_code: 500)
  end

  def login_user(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.email, request.password]
    unless required_fields.all?(&:present?)
      @logger.error("Missing required fields")
      return UserService::LoginUserResponse.new(status_code: 400)
    end

    barrier = Async::Barrier.new

    barrier.async do |task|
      task.async { check_email(request.email) }
      hashed_password = task.async { hash_password(request.password) }
    rescue StandardError => e
      @logger.error("Failed to login user: #{e}")
      return UserService::LoginUserResponse.new(status_code: 400)
    end
    
    @db_pool.with_connection do |conn|
      @logger.debug("Preparing statement")
      conn.prepare("login_user", "SELECT id, two_factor_auth_enabled FROM Users WHERE email = $1 AND psw = $2")

      barrier.wait
      @logger.debug("Querying database for user")
      db_response = conn.exec_prepared("login_user", [request.email, hashed_password])

      if db_response.ntuples.zero?
        @logger.error("User with email '#{request.email}' not found")
        return UserService::LoginUserResponse.new(status_code: 404)
      end

      user_id                 = db_response.getvalue(0, 0)
      two_factor_auth_enabled = db_response.getvalue(0, 1)

      if two_factor_auth_enabled
        @logger.info("User with email '#{request.email}' requires 2FA")
        #TODO send 2FA request (via notification?)
      end

      grpc_request = AuthUserService::GenerateJWTRequest.new(user_id: user_id, auth_level: 1)
      @logger.debug("Sending 'GenerateJWT' request to Auth service: #{grpc_request.inspect}")
      grpc_response = @grpc_client.auth.generate_jwt(grpc_request)
      jwt_token = grpc_response&.jwt_token

      raise "AuthService failed to generate JWT token" unless jwt_token

      @logger.info("User with email '#{request.email}' logged in successfully")
      return UserService::LoginUserResponse.new(status_code: 200, jwt_token: jwt_token)
    end
  rescue PG::UniqueViolation => e
    @logger.error("Unique constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 409)
  rescue PG::CheckViolation => e
    @logger.error("Check constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::NotNullViolation => e
    @logger.error("Not null constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::ForeignKeyViolation => e
    @logger.error("Foreign key constraint violation: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 400)
  rescue PG::Timeout => e
    @logger.error("Database connection timed out: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: 504)
  rescue StandardError => e
    @logger.error("Failed to login user: #{e}")
    UserService::LoginUserResponse.new(status_code: 500)
  ensure
    barrier.stop
  end
  
  def add_friend(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id, request.friend_user_id]
    unless required_fields.all?(&:present?)
      @logger.error("Missing required fields")
      return UserService::AddFriendResponse.new(status_code: 400)
    end

    #TODO implement

  private

  def load_default_avatar
    default_avatar_path = File.join(File.dirname(__FILE__), @config[:avatar][:default])
    avatar              = File.read(default_avatar_path)

    Base64.encode64(avatar)
  end

  def check_email(email)
    @logger.debug("Checking email: #{email}")
    check_email_format(email)
    check_email_domain(email)    
  end

  def check_email_format(email)
    raise "Invalid email format or blacklisted domain" unless EmailValidator.valid?(email, mx: false)
  end
    
  def check_email_domain(email)
    domain = email.split('@').last
    response = @grpc_client.call(AuthUserService::CheckDomainRequest.new(domain: domain))
    raise "Invalid email domain" unless response&.is_allowed
  end

  def check_password(password)
    @psw_format           ||= create_regex_format(@config[:password][:min_length], @config[:password][:max_length], @config[:password][:charset], @config[:password][:policy])

    raise "Invalid password format" unless @psw_format =~ password
  end

  def check_display_name(display_name)
    @dn_format       ||= crete_regex_format(@config[:display_name][:min_length], @config[:display_name][:max_length], @config[:display_name][:charset], @config[:display_name][:policy])

    raise "Invalid display name format" unless @dn_format =~ display_name
  end

  def check_avatar(avatar)
    avatar_decoded = Base64.decode64(request.avatar)
    avatar_image = MiniMagick::Image.read(avatar_decoded)

    raise "Invalid avatar type" unless @config[:avatar][:allowed_types].include?(image.mime_type)
    raise "Avatar size exceeds maximum limit" if avatar.size > @config[:avatar][:max_size]
    raise "Avatar dimensions exceed limit" if image.width > @config[:avatar][:max_dimensions][:width] || image.height > @config[:avatar][:max_dimensions][:height]
  end

  def hash_password(password)
    response = @grpc_client.call(AuthUserService::HashPasswordRequest.new(password: password))
    response&.hashed_password
  end

  def compress_avatar(avatar)
    avatar_decoded = Base64.decode64(avatar)
    avatar_image = MiniMagick::Image.read(avatar_decoded)
    
    avatar_image.format(@config[:avatar][:standard_format])
    avatar_image.to_blob
  end

  def decompress_avatar(avatar)
    avatar_image = MiniMagick::Image.read(avatar)

    avatar_image.format(@config[:avatar][:standard_format])
    processed_avatar_binary_data = avatar_image.to_blob
    
    Base64.encode64(processed_avatar_binary_data)
  end
  
  def create_regex_format(min_length, max_length, charset, policy)
    length_regex = "^.{#{min_length},#{max_length}}$"

    lowercase_pattern  = "[#{charset[:lowercase]}]"
    uppercase_pattern  = "[#{charset[:uppercase]}]"
    digits_pattern     = "[#{charset[:digits]}]"
    special_pattern    = "[#{charset[:special]}]"

    min_uppercase    = "(?=(.*#{uppercase_pattern}){#{policy[:min_uppercase]},})"
    min_lowercase    = "(?=(.*#{lowercase_pattern}){#{policy[:min_lowercase]},})"
    min_digits       = "(?=(.*#{digits_pattern}){#{policy[:min_digits]},})"
    min_special      = "(?=(.*#{special_pattern}){#{policy[:min_special]},})"

    final_regex = "^#{length_regex}#{min_uppercase}#{min_lowercase}#{min_digits}#{min_special}$"

    final_regex
  end

end