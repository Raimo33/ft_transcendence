# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    user_api_gateway_service_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/11/29 13:23:30 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'base64'
require 'mini_magick'
require 'async'
require 'email_validator'
require_relative '../config_handler'
require_relative '../grpc_client'
require_relative '../db_client'
require_relative '../grpc_server'

class UserAPIGatewayServiceHandler < UserAPIGateway::Service
  include ServiceHandlerMiddleware
  include EmailValidator

  def initialize
    @config       = ConfigHandler.instance.config
    @grpc_client  = GrpcClient.instance
    @db_client    = DBClient.instance

    @default_avatar = load_default_avatar
  end

  def ping(_request, _call)
    Google::Protobuf::Empty.new
  end

  def register_user(request, call)
    check_required_fields(request.email, request.password, request.display_name)

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

    barrier.wait
    
    db_response = @db_client.query(
      "INSERT INTO Users (email, psw, display_name, avatar) VALUES ($1, $2, $3, $4) RETURNING id",
      [email, hashed_password, display_name, avatar]
    )

    User::RegisterUserResponse.new(
      user_id: db_response.getvalue(0, 0)
    )
  ensure
    barrier&.stop
  end

  def get_user_profile(request, call)
    check_required_fields(request.user_id)
  
    db_response = @db_client.query(
      "SELECT id, display_name, avatar, status FROM UserProfiles WHERE id = $1", 
      [user_id]
    )

    raise GRPC::NotFound.new("User not found") if db_response.ntuples.zero?

    User::UserPublicProfile.new(
      user_id:      db_response.getvalue(0, 0),
      display_name: db_response.getvalue(0, 1),
      avatar:       db_response.getvalue(0, 2) || @default_avatar,
      status:       db_response.getvalue(0, 3)
    )
  end

  def get_user_status(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(request.user_id)
  
    db_response = @db_client.query(
      "SELECT status FROM UserProfiles WHERE id = $1",
      [user_id]
    )
  
    raise GRPC::NotFound.new("User not found") if db_response.ntuples.zero?
  
    User::UserStatus.new(db_response.getvalue(0, 0))
  end

  def delete_account(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id)

    db_response = @db_client.query(
      "DELETE FROM Users WHERE id = $1",
      [requester_user_id]
    )

    raise GRPC::NotFound.new("User not found") if db_response.cmd_tuples.zero?
  
    Google::Protobuf::Empty.new
  end

  def get_private_profile(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id)

    db_response = @db_client.query(
      "SELECT * FROM UserPrivateProfiles WHERE id = $1",
      [requester_user_id]
    )

    raise GRPC::NotFound.new("User not found") if db_response.ntuples.zero?
  
    User::UserPrivateProfile.new(
      id:            db_response.getvalue(0, 0),
      email:         db_response.getvalue(0, 1),
      display_name:  db_response.getvalue(0, 2),
      avatar:        db_response.getvalue(0, 3) || @default_avatar,
      tfa_status:    db_response.getvalue(0, 4),
      status:        db_response.getvalue(0, 5)
    )
  end

  def update_profile(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id)
    raise GRPC::InvalidArgument.new("No fields to update") unless provided?(request.display_name) || provided?(request.avatar)
  
    barrier = Async::Barrier.new

    barrier.async { check_display_name(request.display_name) } if request.display_name
    barrier.async { check_avatar(request.avatar) }             if request.avatar
  
    compressed_avatar = barrier.async { compress_avatar(request.avatar) } if request.avatar
  
    barrier.wait
  
    updates = []
    params = []
    param_index = 1
  
    if request.display_name
      updates << "display_name = $#{param_index}"
      params << request.display_name
      param_index += 1
    end
  
    if request.avatar
      updates << "avatar = $#{param_index}"
      params << compressed_avatar
      param_index += 1
    end
  
    params << requester_user_id
    
    result = @db_client.query(
      "UPDATE Users SET #{updates.join(', ')} WHERE id = $#{param_index}",
      params
    )

    raise GRPC::NotFound.new("User not found") if result.cmd_tuples.zero?
    
    Google::Protobuf::Empty.new
  ensure
    barrier&.stop
  end

  def enable_tfa(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id)
    
    tasks = Async do |task|
    
      db_task = task.async do
          @db_client.query(
          "SELECT tfa_status FROM Users WHERE id = $1",
          [requester_user_id]
        )
      end

      grpc_task  = task.async do
        grpc_request = AuthUser::GenerateTFASecretRequest.new(requester_user_id)
        @grpc_client.stubs[:auth].generate_tfa_secret(grpc_request)
      end

      db_response = db_task.wait
      raise GRPC::NotFound.new("User not found") if db_response.ntuples.zero?
      
      tfa_status = db_response.getvalue(0, 0)
      raise GRPC::Conflict.new("2FA is already enabled") if tfa_status

      grpc_response = grpc_task.wait
  
      @db_client.query(
        "UPDATE Users SET tfa_status = true, tfa_secret = $1 WHERE id = $2",
        [grpc_response.tfa_secret, requester_user_id]
      )
  
      grpc_response
    end

    tasks.wait
  ensure
    tasks&.stop
  end

  def get_tfa_status(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id)

    db_response = @db_client.query(
      "SELECT tfa_status FROM Users WHERE id = $1",
      [requester_user_id]
    )

    raise GRPC::NotFound.new("User not found") if db_response.ntuples.zero?
  
    tfa_status = db_response.getvalue(0, 0)
    User::TFAStatus.new(tfa_status)
  end

  def disable_tfa(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    raise GRPC::InvalidArgument.new("Missing required fields") unless provided?(requester_user_id)

    result = @db_client.query(
      "SELECT tfa_status FROM Users WHERE id = $1",
      [requester_user_id]
    )

    raise GRPC::NotFound.new("User not found") if result.ntuples.zero?
    raise GRPC::FailedPrecondition.new("2FA is already disabled") unless result[0]['tfa_status']
  
    @db_client.query(
      "UPDATE Users SET tfa_status = false, tfa_secret = NULL WHERE id = $1",
      [requester_user_id]
    )
  
    Google::Protobuf::Empty.new
  end

  def submit_tfa_code(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id, request.tfa_code)
  
    tasks = Async do |task|
      grpc_request = AuthUser::GenerateJWTRequest.new(
        user_id:     requester_user_id,
        auth_level:  2,
        pending_tfa: false
      )
      jwt_task = task.async { @grpc_client.stubs[:auth].generate_jwt(grpc_request) }

      db_response = @db_client.query(
        "SELECT tfa_secret, tfa_status FROM Users WHERE id = $1",
        [requester_user_id]
      )

      raise GRPC::NotFound.new("User not found") if db_response.ntuples.zero?
      
      tfa_secret = db_response.getvalue(0, 0)
      tfa_status = db_response.getvalue(0, 1)
      raise GRPC::FailedPrecondition.new("2FA is not enabled") if tfa_secret.nil? || !tfa_status

      grpc_request  = AuthUser::Check2FACodeRequest.new(
        tfa_secret: tfa_secret,
        tfa_code:   request.tfa_code
      )

      @grpc_client.stubs[:auth].check_tfa_code(grpc_request)

      jwt_response = jwt_task.wait
      User::JWT.new(jwt_response.jwt)
    end

    tasks.wait
  ensure
    tasks&.stop
  end

  def login_user(request, call)
    check_required_fields(request.email, request.password)

    barrier = Async::Barrier.new

    barrier.async { check_email(request.email) }
    hashed_password = barrier.async { hash_password(request.password) }

    db_response = @db_client.query(
      "SELECT id, tfa_status FROM Users WHERE email = $1 AND psw = $2",
      [request.email, hashed_password]
    )

    raise GRPC::NotFound.new("User not found") if db_response.ntuples.zero?

    user_id    = db_response.getvalue(0, 0)
    tfa_status = db_response.getvalue(0, 1)

    grpc_request = AuthUser::GenerateJWTRequest.new(
      user_id:     user_id,
      auth_level:  1,
      pending_tfa: tfa_status
    )
    grpc_response = @grpc_client.stubs[:auth].generate_jwt(grpc_request)

    User::JWT.new(grpc_response.jwt)
  ensure
    barrier&.stop
  end
  
  def add_friend(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(request.requester_user_id, request.friend_user_id)

    db_response = @db_client.query(
      "INSERT INTO Friendships (user_id, friend_id) VALUES ($1, $2)", =
      [requester_user_id, request.friend_user_id]
    )
    
    Google::Protobuf::Empty.new
  end

  def get_friends(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id)

    limit  = request.limit  || 10
    offset = request.offset || 0

    db_response = @db_client.query(
      "SELECT friend_id FROM Friendships WHERE user_id = $1 LIMIT $2 OFFSET $3",
      [requester_user_id, limit, offset]
    )

    raise GRPC::NotFound.new("No friends found") if db_response.ntuples.zero?

    friend_ids = db_response.map { |row| row["friend_id"] }

    User::Friends.new(friend_ids)
  end

  def remove_friend(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id, request.friend_user_id)

    db_response = @db_client.query(
      "DELETE FROM Friends WHERE user_id = $1 AND friend_id = $2",
      [requester_user_id, request.friend_user_id]
    )

    raise GRPC::NotFound.new("Friend not found") if db_response.cmd_tuples.zero?

    Google::Protobuf::Empty.new
  end

  private

  def load_default_avatar
    default_avatar_path = File.join(File.dirname(__FILE__), @config.dig(:avatar, :default_avatar))
    avatar              = File.read(default_avatar_path)

    Base64.encode64(avatar)
  end

  def check_email(email)
    @logger.debug("Checking email: #{email}")
    check_email_format(email)
    check_email_domain(email)
  end

  def check_email_format(email)
    raise GRPC::InvalidArgument.new("Invalid email format") unless EmailValidator.valid?(email, mx: false)
  end

  def check_email_domain(email)
    domain   = email.split('@').last
    request  = AuthUser::CheckDomainRequest.new(domain)
    response = @grpc_client.stubs[:auth].check_domain(request)
    
    raise GRPC::InvalidArgument.new("Invalid email domain") unless response&.is_allowed
  end

  def check_password(password)
    psw_config = @config[:password]
    @psw_format ||= create_regex_format(
      psw_config[:min_length],
      psw_config[:max_length],
      psw_config[:charset],
      psw_config[:policy]
    )

    raise GRPC::InvalidArgument.new("Invalid password format") unless @psw_format =~ password
  end

  def check_display_name(display_name)
    dn_config = @config[:display_name]
    @dn_format ||= create_regex_format(
      dn_config[:min_length],
      dn_config[:max_length],
      dn_config[:charset],
      dn_config[:policy]
    )

    raise GRPC::InvalidArgument.new("Invalid display name format") unless @dn_format =~ display_name
  end

  def check_avatar(avatar)
    avatar_decoded = Base64.decode64(avatar)
    avatar_image   = MiniMagick::Image.read(avatar_decoded)

    raise GRPC::InvalidArgument.new("Invalid avatar type") unless @config.dig(:avatar, :allowed_types).include?(avatar_image.mime_type)
    raise GRPC::InvalidArgument.new("Avatar size exceeds maximum limit") if avatar_image.size > @config.dig(:avatar, :max_size)
  end

  def hash_password(password)
    grpc_request = AuthUser::HashPasswordRequest.new(password)
    response = @grpc_client.stubs[:auth].hash_password(grpc_request)
    raise GRPC::Internal.new("Failed to hash password") unless response&.hashed_password

    response.hashed_password
  end

  def compress_avatar(avatar)
    avatar_decoded = Base64.decode64(avatar)
    avatar_image   = MiniMagick::Image.read(avatar_decoded)
    
    avatar_image.format(@config.dig(:avatar, :format))
    avatar_image.to_blob
  end

  def decompress_avatar(avatar)
    avatar_image = MiniMagick::Image.read(avatar)

    avatar_image.format(@config.dig(:avatar, :format))
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

  private

  def check_required_fields(*fields)
    raise GRPC::InvalidArgument.new("Missing required fields") unless fields.all?(&method(:provided?))
  end

  def provided?(field)
    field.respond_to?(:empty?) ? !field.empty? : !field.nil?
  end

end