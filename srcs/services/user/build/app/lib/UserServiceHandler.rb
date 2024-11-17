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
require_relative "modules/ServerException"
require_relative "../proto/user_pb"
require_relative "../proto/auth_user_pb"

class UserAPIGatewayServiceHandler < UserAPIGatewayService::Service
  include EmailValidator

  def initialize(grpc_client)
    @grpc_client  = grpc_client
    @logger       = ConfigurableLogger.instance.logger
    @config       = ConfigLoader.config

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
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    barrier = Async::Barrier.new

    barrier.async do |task|
      task.async { check_email(request.email) }
      task.async { check_password(request.password) }
      task.async { check_display_name(request.display_name) }
      task.async { check_avatar(request.avatar) } if request.avatar
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
      @logger.debug("Inserting user with email '#{email}' into database")
      db_response = conn.exec_params("INSERT INTO Users (email, psw, display_name, avatar) VALUES ($1, $2, $3, $4) RETURNING id", [email, hashed_password, display_name, avatar])
  
      user_id = db_response.getvalue(0, 0)

      @logger.info("User with email '#{email}' registered successfully")
      UserService::RegisterUserResponse.new(status_code: 201, user_id: user_id)
    end
  #TODO creare DB client che a sua volta ritorna una ServerException in base all'errore PG::*
  rescue ServerException => e
    @logger.error("Failed to register user: #{e.message}")
    UserService::RegisterUserResponse.new(status_code: e.status_code)
  rescue StandardError => e
    @logger.error("Failed to register user: #{e}")
    UserService::RegisterUserResponse.new(status_code: 500)
  ensure
    barrier.stop
  end

  def get_user_profile(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id, request.user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)
  
    @db_pool.with_connection do |conn|
      @logger.debug("Querying database for profile of user with id '#{request.user_id}'")
      db_response = conn.exec_params("SELECT * FROM UserProfiles WHERE user_id = $1", [request.user_id])
      raise ServerException::NotFound("User with id '#{request.user_id}' not found") if db_response.ntuples.zero? 

      user_profile = UserService::UserProfile.new(
        user_id:      db_response.getvalue(0, 0),
        display_name: db_response.getvalue(0, 1),
        avatar:       db_response.getvalue(0, 2) || @default_avatar,
        status:       db_response.getvalue(0, 3)
      )

      @logger.info("User profile for user with id '#{request.user_id}' retrieved successfully")
      UserService::GetUserProfileResponse.new(status_code: 200, profile: user_profile)
    end
  rescue ServerException => e
    @logger.error("Failed to get user profile: #{e.message}")
    UserService::GetUserProfileResponse.new(status_code: e.status_code)
  rescue StandardError => e
    @logger.error("Failed to get user profile: #{e}")
    UserService::GetUserProfileResponse.new(status_code: 500)
  end

  def delete_account(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    @db_pool.with_connection do |conn|
      @logger.debug("Deleting user with id '#{request.requester_user_id}' from database")
      db_response = conn.exec_params("DELETE FROM Users WHERE id = $1", [request.requester_user_id])
      raise ServerException::NotFound("User with id '#{request.requester_user_id}' not found") if db_response.cmd_tuples.zero?
  
      UserService::DeleteAccountResponse.new(status_code: 204)
    end
  rescue ServerException => e
    @logger.error("Failed to delete account: #{e.message}")
    UserService::DeleteAccountResponse.new(status_code: e.status_code)
  rescue StandardError => e
    @logger.error("Failed to delete account: #{e}")
    UserService::DeleteAccountResponse.new(status_code: 500)
  end

  def get_private_profile(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    @db_pool.with_connection do |conn|
      @logger.debug("Querying database for private profile of user with id '#{request.requester_user_id}'")
      db_response = conn.exec_params("SELECT * FROM UserPrivateProfiles WHERE id = $1", [request.requester_user_id])
      raise ServerException::NotFound("Private profile for user with id '#{request.requester_user_id}' not found") if db_response.ntuples.zero?
  
      private_profile = UserService::User.new(
        id:                       db_response.getvalue(0, 0),
        email:                    db_response.getvalue(0, 1),
        display_name:             db_response.getvalue(0, 2),
        avatar:                   db_response.getvalue(0, 3) || @default_avatar,
        two_factor_auth_enabled:  db_response.getvalue(0, 4),
        status:                   db_response.getvalue(0, 5)
      )
  
      @logger.info("Private profile for user with id '#{request.requester_user_id}' retrieved successfully")
      UserService::GetPrivateProfileResponse.new(status_code: 200, profile: private_profile)
    end
  rescue ServerException => e
    @logger.error("Failed to get private profile: #{e.message}")
    UserService::GetPrivateProfileResponse.new(status_code: e.status_code)
  rescue StandardError => e
    @logger.error("Failed to get private profile: #{e}")
    UserService::GetPrivateProfileResponse.new(status_code: 500)
  end

  def update_profile(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    barrier = Async::Barrier.new

    barrier.async do |task|
      task.async { check_display_name(request.display_name) } if request.display_name
      task.async { check_avatar(request.avatar) }             if request.avatar
    end
    barrier.wait

    @db_pool.with_connection do |conn| 
      display_name_response = avatar_response = nil 
      conn.transaction do
        Async do |task|
          display_name_response = task.async do
            @logger.debug("Updating display name for user with id '#{request.requester_user_id}'")
            conn.exec_params("UPDATE Users SET display_name = $1 WHERE user_id = $2", [request.display_name, request.requester_user_id]) if request.display_name
          end
  
          avatar_response = task.async do
            @logger.debug("Updating avatar for user with id '#{request.requester_user_id}'")
            conn.exec_params("UPDATE Users SET avatar = $1 WHERE user_id = $2", [compress_avatar(request.avatar), request.requester_user_id]) if request.avatar
          end

          display_name_response.wait
          avatar_response.wait
        end
      end
  
      if display_name_response&.cmd_tuples.zero? || avatar_response&.cmd_tuples.zero?
        raise ServerException::NotFound("User with id '#{request.requester_user_id}' not found")
      end
  
      @logger.info("Profile for user with id '#{request.requester_user_id}' updated successfully")
      return UserService::UpdateProfileResponse.new(status_code: 204)
    end
  rescue ServerException => e
    @logger.error("Failed to update profile: #{e.message}")
    UserService::UpdateProfileResponse.new(status_code: e.status_code)
  rescue StandardError => e
    @logger.error("Failed to update profile: #{e}")
    UserService::UpdateProfileResponse.new(status_code: 500)
  ensure
    barrier.stop
  end

  def enable_2fa(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)
  
    Async do |task|
      grpc_task = task.async do
        @grpc_client.generate_2fa_secret(request.requester_user_id)
      end

      db_task = task.async do
        @db_pool.with_connection do |conn|
          db_response = conn.exec_params("SELECT two_factor_auth_enabled FROM Users WHERE id = $1", [request.requester_user_id])
          db_response.getvalue(0, 0)
        end
      end

      two_factor_auth_enabled = db_task.wait
      raise ServerException::Conflict("2FA already enabled for user with id '#{request.requester_user_id}'") if two_factor_auth_enabled

      grpc_response = grpc_task.wait
      totp_secret   = grpc_response&.totp_secret
    end

    @db_pool.with_connection do |conn|
      @logger.debug("Updating database to enable 2FA for user with id '#{request.requester_user_id}'")
      conn.exec_params("UPDATE Users SET two_factor_auth_enabled = true, totp_secret = $1 WHERE id = $2", [totp_secret, request.requester_user_id])

      @logger.info("2FA enabled successfully for user with id '#{request.requester_user_id}'")
      return UserService::Enable2FAResponse.new(status_code: 200, totp_secret: totp_secret)
    end
  rescue ServerException => e
    @logger.error("Failed to enable 2FA: #{e.message}")
    UserService::Enable2FAResponse.new(status_code: e.status_code)
  rescue StandardError => e
    @logger.error("Failed to enable 2FA: #{e}")
    UserService::Enable2FAResponse.new(status_code: 500)
  ensure
    grpc_task.stop
    db_task.stop
  end

  def get_2fa_status(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    @db_pool.with_connection do |conn|
      @logger.debug("Querying database for 2FA status of user with id '#{request.requester_user_id}'")
      db_response = conn.exec_params("SELECT two_factor_auth_enabled FROM Users WHERE id = $1", [request.requester_user_id])
      raise ServerException::NotFound("User with id '#{request.requester_user_id}' not found") if db_response.ntuples.zero?
  
      two_factor_auth_enabled = db_response.getvalue(0, 0)
  
      @logger.info("2FA status for user with id '#{request.requester_user_id}' retrieved successfully")
      return UserService::Get2FAStatusResponse.new(status_code: 200, two_factor_auth_enabled: two_factor_auth_enabled)
    end
  rescue ServerException => e
    @logger.error("Failed to get 2FA status: #{e.message}")
    UserService::Get2FAStatusResponse.new(status_code: e.status_code)
  rescue StandardError => e
    @logger.error("Failed to get 2FA status: #{e}")
    UserService::Get2FAStatusResponse.new(status_code: 500)
  end

  #TODO valutare se creare un wrapper con yield anche per gRPC Server
  def disable_2fa(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    @db_pool.with_connection do |conn|
      @logger.debug("Querying database for 2FA status of user with id '#{request.requester_user_id}'")
      db_response = conn.exec_params("SELECT two_factor_auth_enabled FROM Users WHERE id = $1", [request.requester_user_id])
      raise ServerException::NotFound("User with id '#{request.requester_user_id}' not found") if db_response.ntuples.zero?

      two_factor_auth_enabled = db_response.getvalue(0, 0)
      raise ServerException::Conflict("2FA already disabled for user with id '#{request.requester_user_id}'") unless two_factor_auth_enabled

      @logger.debug("Updating database to disable 2FA for user with id '#{request.requester_user_id}'")
      db_response = conn.exec_params("UPDATE Users SET two_factor_auth_enabled = false, totp_secret = NULL WHERE id = $1", [request.requester_user_id])

      @logger.info("2FA disabled successfully for user with id '#{request.requester_user_id}'")
      return UserService::Disable2FAResponse.new(status_code: 204)
    end
  rescue ServerException => e
    @logger.error("Failed to disable 2FA: #{e.message}")
    UserService::Disable2FAResponse.new(status_code: e.status_code)
  rescue StandardError => e
    @logger.error("Failed to disable 2FA: #{e}")
    UserService::Disable2FAResponse.new(status_code: 500)
  end

  def check_2fa_code(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id, request.totp_code]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)
  
    totp_secret = @db_pool.with_connection do |conn|
      @logger.debug("Querying database for 2FA secret of user with id '#{request.requester_user_id}'")
      db_response = conn.exec_params("SELECT totp_secret FROM Users WHERE id = $1", [request.requester_user_id])
      raise ServerException::NotFound("User with id '#{request.requester_user_id}' not found") if db_response.ntuples.zero?
    
      db_response.getvalue(0, 0)
    end
  
    response = @grpc_client.check_2fa_code(totp_secret, request.totp_code)

    @logger.info("2FA code for user with id '#{request.requester_user_id}' checked successfully")
    response.success ? UserService::Check2FACodeResponse.new(status_code: 204) : UserService::Check2FACodeResponse.new(status_code: 401)
  rescue ServerException => e
    @logger.error("Failed to check 2FA code: #{e.message}")
    UserService::Check2FACodeResponse.new(status_code: e.status_code)
  rescue StandardError => e
    @logger.error("Failed to check 2FA code: #{e}")
    UserService::Check2FACodeResponse.new(status_code: 500)
  end

  def login_user(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.email, request.password]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    barrier = Async::Barrier.new

    #TODO fix scoping issue di hashed password
    barrier.async do |task|
      task.async { check_email(request.email) }
      hashed_password = task.async { hash_password(request.password) }
    end
    barrier.wait
    
    @db_pool.with_connection do |conn|
      @logger.debug("Querying database for user with email '#{request.email}'")
      db_response = conn.exec_params("SELECT id, two_factor_auth_enabled FROM Users WHERE email = $1 AND psw = $2", [request.email, hashed_password])
      raise ServerException::NotFound("User with email '#{request.email}' not found") if db_response.ntuples.zero?

      user_id                 = db_response.getvalue(0, 0)
      two_factor_auth_enabled = db_response.getvalue(0, 1)
      logger.info("User with id '#{user_id}' requires 2FA") if two_factor_auth_enabled

      grpc_response = @grpc_client.generate_jwt(user_id, 1, two_factor_auth_enabled)
      jwt           = grpc_response.jwt

      @logger.info("User with email '#{request.email}' logged in successfully")
      return UserService::LoginUserResponse.new(status_code: 200, jwt: jwt)
    end
  rescue ServerException => e
    @logger.error("Failed to login user: #{e.message}")
    UserService::LoginUserResponse.new(status_code: e.status_code)
  rescue StandardError => e
    @logger.error("Failed to login user: #{e}")
    UserService::LoginUserResponse.new(status_code: 500)
  ensure
    barrier.stop
  end
  
  def add_friend(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id, request.friend_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    @db_pool.with_connection do |conn|
      @logger.debug("Inserting friend relationship between users with ids '#{request.requester_user_id}' and '#{request.friend_user_id}' into database")
      db_response = conn.exec_params("INSERT INTO Friendships (user_id, friend_id) VALUES ($1, $2)", [request.requester_user_id, request.friend_user_id])
      #TODO check di db_response??
      @logger.info("Friend relationship between users with ids '#{request.requester_user_id}' and '#{request.friend_user_id}' added successfully")
      return UserService::AddFriendResponse.new(status_code: 201)
    end
  rescue ServerException => e
    @logger.error("Failed to add friend: #{e.message}")
    UserService::AddFriendResponse.new(status_code: e.status_code)
  rescue StandardError => e
    @logger.error("Failed to login user: #{e}")
    UserService::LoginUserResponse.new(status_code: 500)
  end

  def get_friends(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    limit   = request.limit  || 10
    offset  = request.offset || 0

    @db_pool.with_connection do |conn|
      Async do |task|
        user_exists = task.async do
          @logger.debug("Querying database for user with id '#{request.requester_user_id}'")
          db_response = conn.exec_params("SELECT id FROM Users WHERE id = $1", [request.requester_user_id])
          db_response.ntuples.positive?
        end

        friend_ids = task.async do
          @logger.debug("Querying database for friend_ids of user with id '#{request.requester_user_id}'")
          db_response = conn.exec_params("SELECT friend_id FROM Friendships WHERE user_id = $1 LIMIT $2 OFFSET $3", [request.requester_user_id, limit, offset])

          db_response.ntuples.zero? ? [] : db_response.column_values(0)
        end
      end

      user_exists = user_exists.wait
      raise ServerException::NotFound("User with id '#{request.requester_user_id}' not found") unless user_exists

      @logger.info("Friends of user with id '#{request.requester_user_id}' retrieved successfully")
      return UserService::GetFriendsResponse.new(status_code: 200, friend_ids: friend_ids)
    end
  rescue ServerException => e
    @logger.error("Failed to get friends: #{e.message}")
    UserService::GetFriendsResponse.new(status_code: e.status_code)
  rescue StandardError => e
    @logger.error("Failed to login user: #{e}")
    UserService::LoginUserResponse.new(status_code: 500)
  ensure
    user_exists.stop
    friend_ids.stop
  end

  def remove_friend(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id, request.friend_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    @db_pool.with_connection do |conn|
      @logger.debug("Deleting friend relationship between users with ids '#{request.requester_user_id}' and '#{request.friend_user_id}' from database")
      db_response = conn.exec_params("DELETE FROM Friends WHERE user_id = $1 AND friend_id = $2", [request.requester_user_id, request.friend_user_id])
      raise ServerException::NotFound("Friend relationship between users with ids '#{request.requester_user_id}' and '#{request.friend_user_id}' not found") if db_response.cmd_tuples.zero?

      @logger.info("Friend relationship between users with ids '#{request.requester_user_id}' and '#{request.friend_user_id}' removed successfully")
      return UserService::RemoveFriendResponse.new(status_code: 204)
    end
  rescue ServerException => e
    @logger.error("Failed to remove friend: #{e.message}")
    UserService::RemoveFriendResponse.new(status_code: e.status_code)
  rescue StandardError => e
    @logger.error("Failed to login user: #{e}")
    UserService::LoginUserResponse.new(status_code: 500)

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
    unless EmailValidator.valid?(email, mx: false)
      raise ServerExceptions::BadRequest.new("Invalid email format or blacklisted domain")
    end
  end

  def check_email_domain(email)
    domain   = email.split('@').last
    response = @grpc_client.check_domain(domain)
    unless response&.is_allowed
      raise ServerExceptions::BadRequest.new("Invalid email domain")
    end
  end

  def check_password(password)
    @psw_format ||= create_regex_format(
      @config[:password][:min_length],
      @config[:password][:max_length],
      @config[:password][:charset],
      @config[:password][:policy]
    )

    unless @psw_format =~ password
      raise ServerExceptions::BadRequest.new("Invalid password format")
    end
  end

  def check_display_name(display_name)
    @dn_format ||= create_regex_format(
      @config[:display_name][:min_length],
      @config[:display_name][:max_length],
      @config[:display_name][:charset],
      @config[:display_name][:policy]
    )

    unless @dn_format =~ display_name
      raise ServerExceptions::BadRequest.new("Invalid display name format")
    end
  end

  def check_avatar(avatar)
    avatar_decoded = Base64.decode64(avatar)
    avatar_image   = MiniMagick::Image.read(avatar_decoded)

    unless @config[:avatar][:allowed_types].include?(avatar_image.mime_type)
      raise ServerExceptions::BadRequest.new("Invalid avatar type")
    end

    if avatar_image.size > @config[:avatar][:max_size]
      raise ServerExceptions::BadRequest.new("Avatar size exceeds maximum limit")
    end
  end

  def hash_password(password)
    response = @grpc_client.hash_password(password)
    raise ServerExceptions::ServiceUnavailable.new("Password service unavailable") if response.nil?
    raise ServerExceptions::InternalError.new("Failed to hash password") if response.hashed_password.nil?
    response.hashed_password
  end

  def compress_avatar(avatar)
    avatar_decoded = Base64.decode64(avatar)
    avatar_image   = MiniMagick::Image.read(avatar_decoded)
    
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