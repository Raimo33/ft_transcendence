# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    user_api_gateway_service_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2025/01/02 23:24:18 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'base64'
require 'mini_magick'
require 'async'
require 'email_validator'
require 'rqr_code'
require_relative '../config_handler'
require_relative '../grpc_client'
require_relative '../pg_client'
require_relative '../memcached_client'

class UserAPIGatewayServiceHandler < UserAPIGateway::Service
  include EmailValidator

  def initialize
    @config           = ConfigHandler.instance.config
    @grpc_client      = GrpcClient.instance
    @pg_client        = PGClient.instance
    @memcached_client = MemcachedClient.instance

    @default_avatar = load_default_avatar
    @prepared_statements = {
      insert_user: <<~SQL
        INSERT INTO Users (email, psw, display_name, avatar)
        VALUES ($1, $2, $3, $4)
        RETURNING id
      SQL
      get_public_profile: <<~SQL
        SELECT *
        FROM UserPublicProfiles
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
        SELECT *
        FROM UserPrivateProfiles
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
      delete_tfa: <<~SQL
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
      check_friendship: <<~SQL
        SELECT status
        FROM Friendships
        WHERE user_id_1 = $1 AND user_id_2 = $2
      SQL
      insert_friend_request: <<~SQL        
        INSERT INTO Friendships (user_id_1, user_id_2)
        VALUES ($1, $2)
      SQL
      update_friendship: <<~SQL
        UPDATE Friendships
        SET status = $3
        WHERE user_id_1 = $1 AND user_id_2 = $2
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
    
      db_response = @pg_client.exec_prepared(:insert_user, [email, hashed_password, display_name, avatar || @default_avatar])

      UserAPIGateway::RegisterUserResponse.new(db_response.first['id'])
    end

    async_context.wait
  ensure
    checks&.stop
    async_context&.stop
  end

  def get_user_public_profile(request, call)
    check_required_fields(request.id)
  
    db_response = @pg_client.exec_prepared(:get_public_profile, [request.id])
    raise GRPC::NotFound.new("User not found") if db_response.ntuples.zero?

    row = db_response.first
    created_at_time = Time.parse(row["created_at"])
    created_at_timestamp = Google::Protobuf::Timestamp.new
    created_at_timestamp.from_time(created_at_time)
    UserAPIGateway::UserPublicProfile.new(
      user_id:      row["id"],
      display_name: row["display_name"],
      avatar:       row["avatar"] || @default_avatar,
      status:       row["current_status"],
      created_at:   created_at_timestamp
    )
  end

  def get_user_status(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(request.id)

    db_response = @pg_client.exec_prepared(:get_status, [request.id])
    raise GRPC::NotFound.new("User not found") if db_response.ntuples.zero?
  
    UserAPIGateway::UserStatus.new(db_response.first['current_status'])
  end

  def delete_account(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id)

    async_context = Async do |task|
      task.async { forget_past_sessions(requester_user_id) }
      task.async { erase_user_cache(requester_user_id) }
      query_task = task.async { @pg_client.exec_prepared(:delete_user, [requester_user_id]) }
      
      query_result = query_task.wait
      raise GRPC::NotFound.new("User not found") if query_result.cmd_tuples.zero?

      Empty.new
    end
  
    async_context.wait
  ensure
    async_context&.stop
  end

  def get_private_profile(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id)

    db_response = @pg_client.exec_prepared(:get_private_profile, [requester_user_id])
    raise GRPC::NotFound.new("User not found") if db_response.ntuples.zero?
  
    row = db_response.first
    created_at_time = row["created_at"]
    created_at_timestamp = Google::Protobuf::Timestamp.new(seconds: created_at_time.to_i)
    UserAPIGateway::UserPrivateProfile.new(
      id:            row["id"],
      email:         row["email"],
      display_name:  row["display_name"],
      avatar:        row["avatar"] || @default_avatar,
      tfa_status:    row["tfa_status"],
      status:        row["current_status"],
      created_at:    created_at_timestamp
    )
  end

  def update_profile(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id)
    raise GRPC::InvalidArgument.new("No fields to update") unless provided?(request.display_name) || provided?(request.avatar)
  
    async_context = Async do |task|
      checks = Async::Barrier.new

      checks.async { check_display_name(request.display_name) } if request.display_name
      if request.avatar
        checks.async { check_avatar(request.avatar) }
        avatar_task = task.async { compress_avatar(request.avatar) }
      end

      checks.wait
      compressed_avatar = avatar_task&.wait
  
      db_response = @pg_client.exec_prepared(:update_profile, [request.display_name, compressed_avatar, requester_user_id])
      raise GRPC::NotFound.new("User not found") if db_response.cmd_tuples.zero?

      Empty.new
    end

    async_context.wait
  ensure
    async_context&.stop
  end

  def enable_tfa(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id)
    
    tfa_response = @grpc_client.generate_tfa_secret(identifier: requester_user_id)
    
    async_context = Async do |task|
      qr_code_task = task.async { generate_qr_code(tfa_response.tfa_provisioning_uri) }
      db_task = task.async { @pg_client.exec_prepared(:enable_tfa, [requester_user_id, tfa_response.tfa_secret]) }

      db_task.wait
      UserAPIGateway::Enable2FAResponse.new(
        tfa_secret: tfa_response.tfa_secret,
        qr_code:    qr_code_task.wait
      )
    end

    async_context.wait
  ensure
    async_context&.stop
  end

  def disable_tfa(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id, request.code)

    @pg_client.exec_prepared(:get_tfa, [requester_user_id])
    row = db_response.first
    tfa_secret = row['tfa_secret']
    tfa_status = row['tfa_status']
    raise GRPC::FailedPrecondition.new("2FA is not enabled") if !tfa_status || tfa_secret.nil?

    @grpc_client.check_tfa_code(tfa_secret: tfa_secret, tfa_code: request.code)

    db_response = @pg_client.exec_prepared(:delete_tfa, [requester_user_id])
    raise GRPC::NotFound.new("User not found") if db_response.cmd_tuples.zero?
  
    Empty.new
  end

  def submit_tfa_code(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id, request.code)
  
    async_context = Async do |task|
      jwt_generation_task   = task.async { generate_session_jwt(requester_user_id, false) }
      forget_sessions_task  = task.async { forget_past_sessions(requester_user_id) }
      query_task = task.async { @pg_client.exec_prepared(:get_tfa, [requester_user_id]) }

      db_response = query_task.wait
      raise GRPC::NotFound.new("User not found") if db_response.ntuples.zero?
    
      row = db_response.first
      tfa_secret = row['tfa_secret']
      tfa_status = row['tfa_status']
      raise GRPC::FailedPrecondition.new("2FA is not enabled") if !tfa_status || tfa_secret.nil?
      
      @grpc_client.check_tfa_code(tfa_secret: tfa_secret, tfa_code: request.code)

      forget_sessions_task.wait
      @pg_client.exec_prepared(:update_user_status, [requester_user_id, 'online'])

      Common::JWT.new(jwt: jwt_generation_task.wait)
    end

    async_context.wait
  ensure
    async_context&.stop
  end

  def login_user(request, call)
    check_required_fields(request.email, request.password)

    async_context = Async do |task|
      query_result = @pg_client.exec_prepared(:get_login_data, [request.email])
      raise GRPC::NotFound.new("User not found") if query_result.ntuples.zero?

      row = query_result.first
      user_id     = row["id"]
      tfa_status  = row["tfa_status"]
      hashed_psw  = row["psw"]
      user_status = row["current_status"]

      raise GRPC::FailedPrecondition.new("User is banned") if user_status == 'banned'

      validate_password_task = task.async { @grpc_client.validate_password(password: request.password, hashed_password: hashed_psw) }
      session_jwt_task       = task.async { generate_session_jwt(user_id, tfa_status) }
      refresh_jwt_task       = task.async { generate_refresh_jwt(user_id, request.remember_me) }
      forget_sessions_task   = task.async { forget_past_sessions(user_id) }
  
      validate_password_task.wait
      forget_sessions_task.wait
      @pg_client.exec_prepared(:update_user_status, [user_id, 'online']) unless tfa_status
  
      UserAPIGateway::LoginResponse.new(
        tokens: UserAPIGateway::Tokens.new(
          session_token: session_jwt_task.wait,
          refresh_token: refresh_jwt_task.wait
        pending_tfa: tfa_status
        )
      )
    end

    async_context.wait
  ensure
    async_context&.stop
  end

  def refresh_user_session_token(request, call)
    session_token     = call.metadata["session_token"]
    refresh_token     = call.metadata["refresh_token"]
    requester_user_id = call.metadata["requester_user_id"]
    check_required_fields(session_token, refresh_token)

    @grpc_client.validate_refresh_token(refresh_token: refresh_token)

    async_context = Async do |task|
      task.async { forget_past_sessions(requester_user_id) }
      new_jwt_task = task.async { @grpc_client.extend_jwt(jwt: session_token) }

      Common::JWT.new(jwt: new_jwt_task.wait)
    end

    async_context.wait
  ensure
    async_context&.stop
  end

  def logout_user(request, call)
    refresh_token     = call.metadata["refresh_token"]
    requester_user_id = call.metadata["requester_user_id"]
    check_required_fields(refresh_token, requester_user_id)

    async_context = Async do |task|
      task.async { forget_past_sessions(requester_user_id) }
      task.async { @pg_client.exec_prepared(:update_user_status, [requester_user_id, 'offline']) }

      Empty.new
    end

    async_context.wait
  ensure
    async_context&.stop
  end
  
  # def ban_user(request, call)
  #   revoke session e refresh JWT
  #   set user status to 'banned'
  #   only for auth-level 3
  # end
  
  def add_friend(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id, request.id)

    @pg_client.transaction do |tx|
      existing_request = tx.exec_prepared('check_friendship', [friend_user_id, requester_user_id])
  
      if existing_request.ntuples > 0
        status = existing_request[0]['status']
        case status
        when 'pending'
          tx.exec_prepared('update_friendship', [friend_user_id, requester_user_id, 'accepted'])
        when 'accepted'
          raise GRPC::FailedPrecondition.new("Friendship already exists")
        when 'blocked'
          break
      else
        tx.exec_prepared('insert_friend_request', [requester_user_id, friend_user_id])
      end
    end

    @grpc_client.notify_friend_request(from_user_id: requester_user_id, to_user_id: friend_user_id)

    Empty.new
  end

  def get_friends(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id)

    limit  = request.limit  || 10
    offset = request.offset || 0
    
    query_result = @pg_client.exec_prepared(:get_friends, [requester_user_id, limit, offset])
    raise GRPC::NotFound.new("No friends found") if query_result.ntuples.zero?

    friend_ids = query_result.map { |row| row["friend_id"] }
    Common::Identifiers(friend_ids)
  end

  def remove_friend(request, call)
    requester_user_id = call.metadata['requester_user_id']
    check_required_fields(requester_user_id, request.id)
    
    query_result = @pg_client.exec_prepared(:delete_friendship, [requester_user_id, request.id])
    raise GRPC::NotFound.new("Friend not found") if query_result.cmd_tuples.zero?

    Empty.new
  end

  private
    
  def prepare_statements
    barrier   = Async::Barrier.new
    semaphore = Async::Semaphore.new(@config.dig(:postgresql, :pool, :size))

    @prepared_statements.each do |name, sql|
      barrier.async do
        semaphore.acquire do
          @pg_client.prepare(name, sql)
        end
      end
    end

    barrier.wait
  ensure
    barrier.stop
  end

  def forget_past_sessions(user_id)
    now = Time.now.to_i - @config.dig(:tokens, :invalidation_grace_period)
    @memcached_client.set("token_invalid_before:#{user_id}", now)
  end

  def erase_user_cache(user_id)
    async_context = Async do |task|
      task.async { @memcached_client.delete("token_invalid_before:#{user_id}") }
      #TODO other cleanups for keys
    end
    async_context.wait
  ensure
    async_context&.stop
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
    psw_config = @config.fetch(:password)
    @psw_format ||= create_regex_format(
      psw_config.fetch(:min_length),
      psw_config.fetch(:max_length),
      psw_config.fetch(:charset),
      psw_config.fetch(:policy)
    )

    raise GRPC::InvalidArgument.new("Invalid password format") unless @psw_format =~ password
  end

  def check_display_name(display_name)
    dn_config = @config.fetch(:display_name)
    @dn_format ||= create_regex_format(
      dn_config.fetch(:min_length),
      dn_config.fetch(:max_length),
      dn_config.fetch(:charset),
      dn_config.fetch(:policy)
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
    settings = @config.dig(:tokens, :session)

    if pending_tfa
      ttl = settings.fetch(:ttl_pending_tfa)
      auth_level = 1
    else
      ttl = settings.fetch(:ttl)
      auth_level = 2
    end

    @grpc_client.generate_jwt(
      identifier:  user_id,
      ttl:         ttl,
      custom_claims: {
        auth_level: auth_level
      }
    )
  end

  def generate_refresh_jwt(user_id, remember_me)
    @grpc_client.generate_jwt(
      identifier: user_id,
      ttl: @config.dig(:tokens, :refresh, :ttl),
      custom_claims: {
        remember_me: remember_me
      }
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