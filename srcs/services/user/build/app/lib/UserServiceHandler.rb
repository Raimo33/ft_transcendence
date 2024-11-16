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

    @db_connection = PG.connect(db_name:  @config[:database][:name],
                                user:     @config[:database][:user],
                                password: @config[:database][:password], 
                                host:     @config[:database][:host],
                                port:     @config[:database][:port])
                          
    @default_avatar = Base64.encode64(File.read(@config[:avatar][:default]))
  end

  def register_user(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.email, request.password, request.display_name]
    unless required_fields.all?
      @logger.error("Missing required fields")
      return UserAPIGatewayService::RegisterUserResponse.new(status_code: 400)
    end

    Async do |task|
      task.async { check_email(request.email) }
      task.async { check_password(request.password) }
      check_display_name(request.display_name)
      check_avatar(request.avatar) if request.avatar
    rescue StandardError => e
      @logger.error("Failed to register user: #{e}")
      return UserAPIGatewayService::RegisterUserResponse.new(status_code: 400)
    end

    email, hashed_password, display_name, avatar = nil
    Async do |task|
      email = request.email
      task.async { hashed_password = hash_password(request.password) }
      display_name = request.display_name
      avatar = compress_avatar(request.avatar) if request.avatar
    end

    @db_connection.prepare("register_user", "INSERT INTO Users (email, psw, display_name, avatar) VALUES ($1, $2, $3, $4) RETURNING id")
    db_response = @db_connection.exec_prepared("register_user", [email, hashed_password, display_name, avatar])

    user_id = db_response.getvalue(0, 0)
    @logger.info("User with email '#{email}' registered successfully")
    UserService::RegisterUserResponse.new(status_code: 201, user_id: user_id)
  rescue PG::UniqueViolation
    @logger.error("User with email '#{email}' already exists")
    UserService::RegisterUserResponse.new(status_code: 409)
  rescue StandardError => e
    @logger.error("Failed to register user: #{e}")
    UserService::RegisterUserResponse.new(status_code: 500)
  end

  def get_user_profile(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id, request.user_id]

    unless required_fields.all?
      @logger.error("Missing required fields")
      return UserService::GetUserProfileResponse.new(status_code: 400)
    end
  
    @db_connection.prepare("get_user_profile", "SELECT * FROM UserProfiles WHERE user_id = $1")
    db_response = @db_connection.exec_prepared("get_user_profile", [request.user_id])

    if db_response.ntuples.zero?
      @logger.error("User profile for user with id '#{request.user_id}' already exists")
      return UserService::GetUserProfileResponse.new(status_code: 409)
    end

    user_profile = UserService::UserProfile.new(
      user_id:      db_response.getvalue(0, 0),
      display_name: db_response.getvalue(0, 1),
      avatar:       db_response.getvalue(0, 2) || @default_avatar,
      status:       db_response.getvalue(0, 3)
    )

    @logger.info("User profile for user with id '#{request.user_id}' retrieved successfully")
    UserService::GetUserProfileResponse.new(status_code: 200, profile: user_profile)
  rescue StandardError => e
    @logger.error("Failed to get user profile: #{e}")
    UserService::GetUserProfileResponse.new(status_code: 500)
  end

  def delete_account(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    unless required_fields.all?
      @logger.error("Missing required fields")
      return UserService::DeleteAccountResponse.new(status_code: 400)
    end

    @db_connection.prepare("delete_account", "DELETE FROM Users WHERE id = $1")
    db_response = @db_connection.exec_prepared("delete_account", [request.requester_user_id])

    if db_response.cmd_tuples.zero?
      @logger.error("User with id '#{request.requester_user_id}' not found")
      return UserService::DeleteAccountResponse.new(status_code: 404)
    end

    UserService::DeleteAccountResponse.new(status_code: 200)
  rescue StandardError => e
    @logger.error("Failed to delete account: #{e}")
    UserService::DeleteAccountResponse.new(status_code: 500)
  end

  def get_private_profile(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.requester_user_id]
    unless required_fields.all?
      @logger.error("Missing required fields")
      return UserService::GetPrivateProfileResponse.new(status_code: 400)
    end

    @db_connection.prepare("get_private_profile", "SELECT * FROM UserPrivateProfiles WHERE id = $1")
    db_response = @db_connection.exec_prepared("get_private_profile", [request.requester_user_id])

    if db_response.ntuples.zero?
      @logger.error("Private profile for user with id '#{request.requester_user_id}' not found")
      return UserService::GetPrivateProfileResponse.new(status_code: 404)
    end

    private_profile = UserService::User.new(
      id:                       db_response.getvalue(0, 0),
      email:                    db_response.getvalue(0, 1),
      display_name:             db_response.getvalue(0, 2),
      avatar:                   db_response.getvalue(0, 3) || @default_avatar,
      two_factor_auth_enabled:  db_response.getvalue(0, 4)
      status:                   db_response.getvalue(0, 5)
    )

    @logger.info("Private profile for user with id '#{request.requester_user_id}' retrieved successfully")
    UserService::GetPrivateProfileResponse.new(status_code: 200, profile: private_profile)
  rescue StandardError => e
    @logger.error("Failed to get private profile: #{e}")
    UserService::GetPrivateProfileResponse.new(status_code: 500)
  end

  #TODO add more methods

  private

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