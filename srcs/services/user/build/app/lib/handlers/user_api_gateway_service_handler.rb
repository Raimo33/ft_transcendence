# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    user_api_gateway_service_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 22:06:14 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'base64'
require 'mini_magick'
require 'async'
require 'email_validator'
require_relative '../config_handler'
require_relative '../grpc_client'
require_relative '../db_client'

class UserAPIGatewayServiceHandler < UserAPIGateway::Service
  include EmailValidator

  def initialize
    @config       = ConfigHandler.instance.config
    @grpc_client  = GrpcClient.instance
    @db_client    = DBClient.instance

    @default_avatar = load_default_avatar
    @prepared_statements = {
      insert_user: <<~SQL
        INSERT INTO Users (email, psw, display_name, avatar)
        VALUES ($1, $2, $3, $4)
        RETURNING id
      SQL
      get_public_profile: <<~SQL
        SELECT id, display_name, avatar, current_status
        FROM UserProfiles
        WHERE id = $1
      SQL
      get_status: <<~SQL
        SELECT current_status
        FROM UserProfiles
        WHERE id = $1
      SQL
      delete_user: <<~SQL
        DELETE FROM Users 
        WHERE id = $1
      SQL
      get_private_profile: <<~SQL
        SELECT * FROM UserPrivateProfiles
        WHERE id = $1
      SQL
      update_profile: <<~SQL
        UPDATE Users
        SET 
          display_name = COALESCE($1, display_name),
          avatar = COALESCE($2, avatar)
        WHERE id = $3
      SQL
      enable_tfa: <<~SQL
        UPDATE Users 
        SET tfa_status = true, 
            tfa_secret = $2 
        WHERE id = $1 AND tfa_status = false
      SQL
      disable_tfa: <<~SQL
        UPDATE Users
        SET tfa_status = false, tfa_secret = NULL
        WHERE id = $1 AND tfa_status = true
      SQL
      get_tfa: <<~SQL
        SELECT tfa_secret, tfa_status
        FROM Users
        WHERE id = $1
      SQL
      get_login_data: <<~SQL
        SELECT id, psw, tfa_status, current_status
        FROM Users
        WHERE email = $1
      SQL
      update_user_status: <<~SQL
        UPDATE UserProfiles
        SET current_status = $2
        WHERE id = $1
      SQL
      insert_friendship: <<~SQL
        INSERT INTO Friendships (user_id_1, user_id_2)
        VALUES ($1, $2)
      SQL
      get_friends: <<~SQL
        SELECT friend_id
        FROM Friendships
        WHERE user_id = $1
        LIMIT $2 OFFSET $3
      SQL
      delete_friendship: <<~SQL
        DELETE FROM Friendships
        WHERE user_id_1 = $1 AND user_id_2 = $2
      SQL
    }

    prepare_statements
  end

  def ping(request, call)
    Empty.new
  end

  def register_user(request, call)
    check_required_fields(request.email, request.password, request.display_name)

    checks = Async::Barrier.new
    async_context = Async do |task|
      email        = request.email
      display_name = request.display_name
  
      checks.async { check_email(email) }
      checks.async { check_password(request.password) }
      checks.async { check_display_name(display_name) }

      if request.avatar
        checks.async { check_avatar(request.avatar) }
        avatar_task = task.async { compress_avatar(request.avatar) }
      end

      password_task  = task.async { hash_password(request.password) }

      checks.wait
      hashed_password = password_task.wait
      avatar = avatar_task&.wait
    
      insert_result = @db_client.exec_prepared(:insert_user, [email, hashed_password, display_name, avatar || @default_avatar])

      UserAPIGateway::RegisterUserResponse.new(insert_result[0]['id'])
    end.wait
  ensure
    checks&.stop
    async_context&.stop
  end

  def get_user_public_profile(request, call)
    check_required_fields(request.id)
  
    query_result = @db_client.exec_prepared(:get_public_profile, [request.id])
    raise GRPC::NotFound.new("User not found") if query_result.ntuples.zero?

    row = query_result.first
    UserAPIGateway::UserPublicProfile.new(
      user_id:      row["id"],
      display_name: row["display_name"],
      avatar:       row["avatar"] || @default_avatar,
      status:       row["current_status"]
    )
  end

  def get_user_status(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(request.id)

    query_result = @db_client.exec_prepared(:get_status, [request.id])
    raise GRPC::NotFound.new("User not found") if query_result.ntuples.zero?
  
    UserAPIGateway::UserStatus.new(query_result[0]['current_status'])
  end

  def delete_account(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id)

    query_result = @db_client.exec_prepared(:delete_user, [requester_user_id])
    raise GRPC::NotFound.new("User not found") if query_result.cmd_tuples.zero?
  
    Empty.new
  end

  def get_private_profile(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id)

    query_result = @db_client.exec_prepared(:get_private_profile, [requester_user_id])
    raise GRPC::NotFound.new("User not found") if query_result.ntuples.zero?
  
    row = query_result.first
    UserAPIGateway::UserPrivateProfile.new(
      id:            row["id"],
      email:         row["email"],
      display_name:  row["display_name"],
      avatar:        row["avatar"] || @default_avatar,
      tfa_status:    row["tfa_status"]
      status:        row["current_status"]
    )
  end

  def update_profile(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id)
    raise GRPC::InvalidArgument.new("No fields to update") unless provided?(request.display_name) || provided?(request.avatar)
  
    checks = Async::Barrier.new

    checks.async { check_display_name(request.display_name) } if request.display_name
    if request.avatar
      checks.async { check_avatar(request.avatar) }
      avatar_task = Async { compress_avatar(request.avatar) }
    end

    checks.wait
    compressed_avatar = avatar_task&.wait
  
    query_result = @db_client.exec_prepared(:update_profile, [request.display_name, compressed_avatar, requester_user_id])
    raise GRPC::NotFound.new("User not found") if query_result.cmd_tuples.zero?

    Empty.new
  ensure
    checks&.stop
    avatar_task&.stop
  end

  def enable_tfa(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id)
    
    tfa_response = @grpc_client.generate_tfa_secret(identifier: requester_user_id)
    
    qr_code_task = Async { generate_qr_code(tfa_response.tfa_provisioning_uri) }
    db_task = Async { @db_client.query(@prepared_statements[:enable_tfa], [requester_user_id, tfa_response.tfa_secret]) }

    qr_code = qr_code_task.wait
    db_task.wait
    UserAPIGateway::Enable2FAResponse.new(
      tfa_secret: tfa_response.tfa_secret,
      qr_code:    qr_code
    )
  ensure
    qr_code_task&.stop
    db_task&.stop
  end

  def disable_tfa(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id)

    query_result = @db_client.exec_prepared(:disable_tfa, [requester_user_id])
    raise GRPC::NotFound.new("User not found") if query_result.cmd_tuples.zero?
  
    Empty.new
  end

  def submit_tfa_code(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id, request.code)
  
    session_jwt_task = Async { generate_session_jwt(requester_user_id, false) }
    refresh_jwt_task = Async { @grpc_client.rotate_jwt(jwt: call.metadata["refresh_token"]) }
    
    query_result = @db_client.exec_prepared(:get_tfa, [requester_user_id])
    raise GRPC::NotFound.new("User not found") if query_result.ntuples.zero?
    
    tfa_secret = query_result[0]['tfa_secret']
    tfa_status = query_result[0]['tfa_status']
    raise GRPC::FailedPrecondition.new("2FA is not enabled") if !tfa_status || tfa_secret.nil?

    check_tfa_code(request.code, tfa_secret)
    @db_client.exec_prepared(:update_user_status, [requester_user_id, 'online'])
    @grpc_client.revoke_jwt(jwt: call.metadata["session_token"])

    UserAPIGateway::Tokens.new(
      session_token: session_jwt_task.wait,
      refresh_token: refresh_jwt_task.wait
    )
  ensure
    session_jwt_task&.stop
    refresh_jwt_task&.stop
  end

  def login_user(request, call)
    check_required_fields(request.email, request.password)

    async_context = Async do |task|
      task.async { check_email(request.email) }
    
      query_result = @db_client.exec_prepared(:get_login_data, [request.email])
      raise GRPC::NotFound.new("User not found") if query_result.ntuples.zero?

      user_id     = query_result[0]["id"]
      tfa_status  = query_result[0]["tfa_status"]
      hashed_psw  = query_result[0]["psw"]
      user_status = query_result[0]["current_status"]

      raise GRPC::FailedPrecondition.new("User is banned") if user_status == 'banned'

      task.async { validate_password(request.password, hashed_psw) }

      session_jwt_task = task.async { generate_session_jwt(user_id, tfa_status) }
      refresh_jwt_task = task.async do
        @grpc_client.generate_jwt(
          identifier: user_id,
          expire_after: @config[:tokens][:refresh][:ttl]
          custom_claims: { remember_me: request.remember_me }
        )
      end

      @db_client.exec_prepared(:update_user_status, [user_id, 'online']) unless tfa_status
  
      UserAPIGateway::LoginResponse.new(
        tokens: UserAPIGateway::Tokens.new(
          session_token: session_jwt_task.wait,
          refresh_token: refresh_jwt_task.wait
        pending_tfa: tfa_status
        )
      )
    end.wait
  ensure
    async_context&.stop
  end

  def refresh_user_token(request, call)
    session_token = call.metadata["session_token"]
    refresh_token = call.metadata["refresh_token"]
    check_required_fields(session_token, refresh_token)

    @grpc_client.validate_jwt(jwt: refresh_token)

    session_jwt_task = Async { @grpc_client.rotate_jwt(jwt: session_token) }
    refresh_jwt_task = Async { @grpc_client.rotate_jwt(jwt: refresh_token) }

    UserAPIGateway::Tokens.new(
      session_token: session_jwt_task.wait,
      refresh_token: refresh_jwt_task.wait
    )
  ensure
    session_jwt_task&.stop
    refresh_jwt_task&.stop
  end

  #TODO: implement
  def logout_user(request, call)
    #revoke session JWT
    #revoke refresh JWT
    #update user status
  end
  
  # def ban_user(request, call)
  #   revoke session e refresh JWT
  #   set user status to 'banned'
  #   only for auth-level 3
  # end
  
  def add_friend(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id, request.id)

    query_result = @db_client.exec_prepared(:insert_friendship, [requester_user_id, request.id])

    Empty.new
  end

  def get_friends(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id)

    limit  = request.limit  || 10
    offset = request.offset || 0
    
    query_result = @db_client.exec_prepared(:get_friends, [requester_user_id, limit, offset])
    raise GRPC::NotFound.new("No friends found") if query_result.ntuples.zero?

    friend_ids = query_result.map { |row| row["friend_id"] }
    UserAPIGateway::UserIds(friend_ids)
  end

  def remove_friend(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id, request.id)
    
    query_result = @db_client.exec_prepared(:delete_friendship, [requester_user_id, request.id])
    raise GRPC::NotFound.new("Friend not found") if query_result.cmd_tuples.zero?

    Empty.new
  end

  private
    
  def prepare_statements
    barrier   = Async::Barrier.new
    semaphore = Async::Semaphore.new(@db_client.pool_size)

    @prepared_statements.each do |name, sql|
      barrier.async do
        semaphore.acquire do
          @db_client.prepare(name, sql)
        end
      end
    end

    barrier.wait
  ensure
    barrier.stop
  end

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
    response = @grpc_client.check_domain(domain: domain)
    
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
    response = @grpc_client.hash_password(password: password)

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
    
    "data:image/#{avatar_image.type.downcase};base64,#{Base64.strict_encode64(processed_avatar_binary_data)}"
  end

  def generate_qr_code(uri)
    qr_code = RQRCode::QRCode.new(uri)

    png = qr_code.as_png(
      bit_depth: 1,
      border_modules: 4,
      color_mode: ChunkyPNG::COLOR_GRAYSCALE,
      color: 'black',
      file: nil,
      fill: 'white',
      module_px_size: 6,
      resize_exactly_to: false,
      resize_gte_to: false
    )

    "data:image/png;base64,#{Base64.strict_encode64(png.to_s)}"
  end
  
  def generate_session_jwt(user_id, pending_tfa)
    settings = @config[:tokens][:session]

    if pending_tfa
      expire_after = settings[:ttl_pending_tfa]
      auth_level = 1
    else
      expire_after = settings[:ttl]
      auth_level = 2
    end

    @grpc_client.generate_jwt(
      identifier:   user_id,
      expire_after: expire_after,
      custom_claims: { auth_level: auth_level }
    )
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

  def check_required_fields(*fields)
    raise GRPC::InvalidArgument.new("Missing required fields") unless fields.all?(&method(:provided?))
  end

  def provided?(field)
    field.respond_to?(:empty?) ? !field.empty? : !field.nil?
  end

end