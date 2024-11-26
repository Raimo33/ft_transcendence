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
require_relative "singletons/ConfigHandler"
require_relative "modules/DBClientErrorHandler"
require_relative "../proto/user_pb"
require_relative "../proto/auth_user_pb"

class UserAPIGatewayServiceHandler < UserAPIGatewayService::Service
  include EmailValidator

  def initialize(grpc_client)
    @config         = ConfigHandler.instance.config
    @grpc_client    = grpc_client
    @db_client      = DBClient.instance

    @default_avatar = load_default_avatar
  end

  def register_user(request, _metadata)
    required_fields = [request.email, request.password, request.display_name]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    barrier = Async::Barrier.new

    barrier.async { check_email(request.email) }
    barrier.async { check_password(request.password) }
    barrier.async { check_display_name(request.display_name) }
    barrier.async { check_avatar(request.avatar) } if request.avatar

    barrier.wait

    email            = request.email
    display_name     = request.display_name
    hashed_password  = barrier.async { hash_password(request.password) }
    avatar           = barrier.async { compress_avatar(request.avatar) } if request.avatar

    barrier.async do
      db_response = @db_client.query("SELECT id FROM Users WHERE email = $1", [email])
      raise ServerException::Conflict("User with email '#{email}' already exists") if db_response.ntuples.positive?
    end
    barrier.async do
      db_response = @db_client.query("SELECT id FROM UserProfiles WHERE display_name = $1", [display_name])
      raise ServerException::Conflict("User with display name '#{display_name}' already exists") if db_response.ntuples.positive?
    end

    barrier.wait
    
    db_response = @db_client.query("INSERT INTO Users (email, psw, display_name, avatar) VALUES ($1, $2, $3, $4) RETURNING id", [email, hashed_password, display_name, avatar])
    raise ServerException::InternalError("Failed to register user") if db_response.ntuples.zero?

    user_id = db_response.getvalue(0, 0)
    UserService::RegisterUserResponse.new(status_code: 201, user_id: user_id)
  rescue ServerException => e
    UserService::RegisterUserResponse.new(status_code: e.status_code)
  rescue StandardError => e
    UserService::RegisterUserResponse.new(status_code: 500)
  ensure
    barrier.stop
  end

  def get_user_profile(request, _metadata)
    required_fields = [request.requester_user_id, request.user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)
  
    db_response = @db_client.query("SELECT id, display_name, avatar, status FROM UserProfiles WHERE id = $1", [request.user_id])
    raise ServerException::NotFound("Profile for user with id '#{request.user_id}' not found") if db_response.ntuples.zero?

    user_profile = UserService::UserProfile.new(
      user_id:      db_response.getvalue(0, 0),
      display_name: db_response.getvalue(0, 1),
      avatar:       db_response.getvalue(0, 2) || @default_avatar,
      status:       db_response.getvalue(0, 3)
    )

    UserService::GetUserPublicProfileResponse.new(status_code: 200, profile: user_profile)
  rescue ServerException => e
    UserService::GetUserPublicProfileResponse.new(status_code: e.status_code)
  rescue StandardError => e
    UserService::GetUserPublicProfileResponse.new(status_code: 500)
  end

  def delete_account(request, _metadata)
    required_fields = [request.requester_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    db_response = @db_client.query("DELETE FROM Users WHERE id = $1", [request.requester_user_id])
    raise ServerException::NotFound("User with id '#{request.requester_user_id}' not found") if db_response.cmd_tuples.zero?
  
    UserService::DeleteAccountResponse.new(status_code: 204)
  rescue ServerException => e
    UserService::DeleteAccountResponse.new(status_code: e.status_code)
  rescue StandardError => e
    UserService::DeleteAccountResponse.new(status_code: 500)
  end

  def get_private_profile(request, _metadata)
    required_fields = [request.requester_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    db_response = @db_client.query("SELECT * FROM UserPrivateProfiles WHERE id = $1", [request.requester_user_id])
    raise ServerException::NotFound("Private profile for user with id '#{request.requester_user_id}' not found") if db_response.ntuples.zero?
  
    private_profile = UserService::User.new(
      id:                       db_response.getvalue(0, 0),
      email:                    db_response.getvalue(0, 1),
      display_name:             db_response.getvalue(0, 2),
      avatar:                   db_response.getvalue(0, 3) || @default_avatar,
      tfa_status:  db_response.getvalue(0, 4),
      status:                   db_response.getvalue(0, 5)
    )
  
    UserService::GetUserPrivateProfileResponse.new(status_code: 200, profile: private_profile)
  rescue ServerException => e
    UserService::GetUserPrivateProfileResponse.new(status_code: e.status_code)
  rescue StandardError => e
    UserService::GetUserPrivateProfileResponse.new(status_code: 500)
  end

  def update_profile(request, _metadata)

    required_fields = [request.requester_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    barrier = Async::Barrier.new
    tasks   = []

    if request.display_name
      tasks << barrier.async do
        check_display_name(request.display_name)
        @db_client.query("UPDATE Users SET display_name = $1 WHERE id = $2", [request.display_name, request.requester_user_id])
        raise ServerException::InternalError("Failed to update display name") if db_response.cmd_tuples.zero?
      end
    end

    if request.avatar
      tasks << barrier.async do
        check_avatar(request.avatar)
        compressed_avatar = compress_avatar(request.avatar)
        @db_client.query("UPDATE Users SET avatar = $1 WHERE id = $2", [compressed_avatar, request.requester_user_id])
        raise ServerException::InternalError("Failed to update avatar") if db_response.cmd_tuples.zero?
      end
    end

    barrier.wait
  
    return UserService::UpdateProfileResponse.new(status_code: 204)
  rescue ServerException => e
    UserService::UpdateProfileResponse.new(status_code: e.status_code)
  rescue StandardError => e
    UserService::UpdateProfileResponse.new(status_code: 500)
  ensure
    barrier.stop
  end

  def enable_tfa(request, _metadata)
    required_fields = [request.requester_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)
  
    db_task = Async do
      @db_client.query("SELECT tfa_status FROM Users WHERE id = $1", [request.requester_user_id])
    end
    grpc_task = Async do
      @grpc_client.generate_tfa_secret(request.requester_user_id)
    end

    db_response = db_task.wait
    raise ServerException::NotFound("User with id '#{request.requester_user_id}' not found") if db_response.ntuples.zero?
    tfa_status = db_response.getvalue(0, 0)
    raise ServerException::Conflict("2FA already enabled for user with id '#{request.requester_user_id}'") if tfa_status

    grpc_response = grpc_task.wait
    totp_secret   = grpc_response.totp_secret

    @db_client.query("UPDATE Users SET tfa_status = true, totp_secret = $1 WHERE id = $2", [totp_secret, request.requester_user_id])
  
    UserService::EnableTFAResponse.new(status_code: 200, totp_secret: totp_secret)
  rescue ServerException => e
    UserService::EnableTFAResponse.new(status_code: e.status_code)
  rescue StandardError => e
    UserService::EnableTFAResponse.new(status_code: 500)
  ensure
    db_task.stop
    grpc_task.stop
  end

  def get_tfa_status(request, _metadata)
    required_fields = [request.requester_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    db_response = @db_client.query("SELECT tfa_status FROM Users WHERE id = $1", [request.requester_user_id])
    raise ServerException::NotFound("User with id '#{request.requester_user_id}' not found") if db_response.ntuples.zero?
  
    tfa_status = db_response.getvalue(0, 0)
  
    UserService::GetTFAStatusResponse.new(status_code: 200, tfa_status: tfa_status)
  rescue ServerException => e
    UserService::GetTFAStatusResponse.new(status_code: e.status_code)
  rescue StandardError => e
    UserService::GetTFAStatusResponse.new(status_code: 500)
  end

  def disable_tfa(request, _metadata)  
    required_fields = [request.requester_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)
  
    db_response = @db_client.query("UPDATE Users SET tfa_status = false, totp_secret = NULL WHERE id = $1 AND tfa_status = true", [request.requester_user_id])
  
    if db_response.cmd_tuples.zero?
      db_response = @db_client.query("SELECT 1 FROM Users WHERE id = $1", [request.requester_user_id])
      user_exists = db_response.ntuples.positive?
      if user_exists
        raise ServerException::Conflict("2FA is already disabled for user with id '#{request.requester_user_id}'")
      else
        raise ServerException::NotFound("User with id '#{request.requester_user_id}' not found")
      end
    end
  
    UserService::DisableTFAResponse.new(status_code: 204)
  rescue ServerException => e
    UserService::DisableTFAResponse.new(status_code: e.status_code)
  rescue StandardError => e
    UserService::DisableTFAResponse.new(status_code: 500)
  end  

  def check_tfa_code(request, _metadata)
    required_fields = [request.requester_user_id, request.totp_code]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)
  
    db_response = @db_client.query("SELECT totp_secret FROM Users WHERE id = $1", [request.requester_user_id])
    raise ServerException::NotFound("User with id '#{request.requester_user_id}' not found") if db_response.ntuples.zero?
    
    totp_secret = db_response.getvalue(0, 0)

    grpc_response = @grpc_client.check_tfa_code(totp_secret, request.totp_code)
    code_valid    = grpc_response.success

    code_valid ? UserService::CheckTFACodeResponse.new(status_code: 204) : UserService::CheckTFACodeResponse.new(status_code: 401)
  rescue ServerException => e
    UserService::CheckTFACodeResponse.new(status_code: e.status_code)
  rescue StandardError => e
    UserService::CheckTFACodeResponse.new(status_code: 500)
  end

  def login_user(request, _metadata)
    required_fields = [request.email, request.password]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    barrier = Async::Barrier.new

    barrier.async { check_email(request.email) }
    hashed_password = barrier.async { hash_password(request.password) }

    db_response = @db_client.query("SELECT id, tfa_status FROM Users WHERE email = $1 AND psw = $2", [request.email, hashed_password]) do |conn|
    raise ServerException::NotFound("User with email '#{request.email}' not found") if db_response.ntuples.zero?

    user_id                 = db_response.getvalue(0, 0)
    tfa_status = db_response.getvalue(0, 1)

    logger.info("User with id '#{user_id}' requires 2FA") if tfa_status

    grpc_response = @grpc_client.generate_jwt(user_id, 1, tfa_status)
    jwt           = grpc_response.jwt

    UserService::LoginUserResponse.new(status_code: 200, jwt: jwt)
  rescue ServerException => e
    UserService::LoginUserResponse.new(status_code: e.status_code)
  rescue StandardError => e
    UserService::LoginUserResponse.new(status_code: 500)
  ensure
    barrier.stop
  end
  
  def add_friend(request, _metadata)
    required_fields = [request.requester_user_id, request.friend_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    db_response = @db_client.query("INSERT INTO Friendships (user_id, friend_id) VALUES ($1, $2)", [request.requester_user_id, request.friend_user_id])
    raise ServerException::Conflict("Friend relationship between users with ids '#{request.requester_user_id}' and '#{request.friend_user_id}' already exists") if db_response.cmd_tuples.zero?
    
    return UserService::AddFriendResponse.new(status_code: 201)
  rescue ServerException => e
    UserService::AddFriendResponse.new(status_code: e.status_code)
  rescue StandardError => e
    UserService::LoginUserResponse.new(status_code: 500)
  end

  def get_friends(request, _metadata)
    required_fields = [request.requester_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    limit  = request.limit  || 10
    offset = request.offset || 0

    db_response = @db_client.query("SELECT friend_id FROM Friendships WHERE user_id = $1 LIMIT $2 OFFSET $3", [request.requester_user_id, limit, offset])
    raise ServerException::NotFound("User with id '#{request.requester_user_id}' not found") if db_response.ntuples.zero?

    friend_ids = db_response.map { |row| row["friend_id"] }

    UserService::GetFriendsResponse.new(status_code: 200, friend_ids: friend_ids)
  rescue ServerException => e
    UserService::GetFriendsResponse.new(status_code: e.status_code)
  rescue StandardError => e
    UserService::LoginUserResponse.new(status_code: 500)
  end

  def remove_friend(request, _metadata)
    required_fields = [request.requester_user_id, request.friend_user_id]
    raise ServerException::BadRequest("Missing required fields") unless required_fields.all?(&:present?)

    db_response = @db_client.query("DELETE FROM Friends WHERE user_id = $1 AND friend_id = $2", [request.requester_user_id, request.friend_user_id])
    raise ServerException::NotFound("Friend relationship between users with ids '#{request.requester_user_id}' and '#{request.friend_user_id}' not found") if db_response.cmd_tuples.zero?

    UserService::RemoveFriendResponse.new(status_code: 204)
  rescue ServerException => e
    UserService::RemoveFriendResponse.new(status_code: e.status_code)
  rescue StandardError => e
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

    min_uppercase  = "(?=(.*#{uppercase_pattern}){#{policy[:min_uppercase]},})"
    min_lowercase  = "(?=(.*#{lowercase_pattern}){#{policy[:min_lowercase]},})"
    min_digits     = "(?=(.*#{digits_pattern}){#{policy[:min_digits]},})"
    min_special    = "(?=(.*#{special_pattern}){#{policy[:min_special]},})"

    "^#{length_regex}#{min_uppercase}#{min_lowercase}#{min_digits}#{min_special}$"
  end

end