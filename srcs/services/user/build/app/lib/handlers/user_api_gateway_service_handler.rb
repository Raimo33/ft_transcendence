# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    user_api_gateway_service_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/11/30 12:18:57 by craimond         ###   ########.fr        #
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

#TODO usare prepare and execute per le query
#TODO usare transactions per le query che necessitano di più operazioni
#TODO invece di fare piu operazioni nelle queries fare una sola operazione e solo in caso di ntuples zero controllare la causa dell'errore con una altra query

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

    checks = Async::Barrier.new
    result = Async do |task|
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
    
      @db_client.transaction do |conn|
        insert_query = <<~SQL
          INSERT INTO Users (email, psw, display_name, avatar)
          VALUES ($1, $2, $3, $4)
          ON CONFLICT ON CONSTRAINT unq_users_email DO NOTHING
          ON CONFLICT ON CONSTRAINT unq_users_display_name DO NOTHING
          RETURNING id
        SQL

        insert_result = conn.exec_params(insert_query, [email, hashed_password, display_name, avatar])
        if insert_result.ntuples.zero?
          email_exists_query = <<~SQL
            SELECT EXISTS(SELECT 1 FROM Users WHERE email = $1)
          SQL
          email_exists_result = conn.exec_params(email_exists_query, [email])
          raise GRPC::AlreadyExists.new("Email already in use") if email_exists_result[0][0] == 't'
          raise GRPC::AlreadyExists.new("Display name taken")
        end

        UserAPIGateway::RegisterUserResponse.new(insert_result[0]['id'])
      end
    end.wait
  ensure
    checks&.stop
    result&.stop
  end

  def get_user_profile(request, call)
    check_required_fields(request.user_id)
  
    db_query = <<~SQL
      SELECT id, display_name, avatar, status
      FROM UserProfiles
      WHERE id = $1
    SQL

    query_result = @db_client.query(db_query, [request.user_id])
    raise GRPC::NotFound.new("User not found") if query_result.ntuples.zero?

    row = query_result.first
    UserAPIGateway::UserPublicProfile.new(
      user_id:      row["id"],
      display_name: row["display_name"],
      avatar:       row["avatar"] || @default_avatar,
      status:       row["status"]
    )
  end

  def get_user_status(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(request.user_id)
  
    db_query = <<~SQL
      SELECT status
      FROM UserProfiles
      WHERE id = $1
    SQL

    query_result = @db_client.query(db_query, [request.user_id])
    raise GRPC::NotFound.new("User not found") if query_result.ntuples.zero?
  
    UserAPIGateway::UserStatus.new(query_result[0]['status'])
  end

  def delete_account(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id)

    db_query = <<~SQL
      WITH user_check AS (
        SELECT id, tfa_status 
        FROM Users 
        WHERE id = $1
        FOR UPDATE
      )
      DELETE FROM Users 
      WHERE id = $1 
        AND EXISTS (SELECT 1 FROM user_check)
      RETURNING id
    SQL

    query_result = @db_client.query(db_query, [requester_user_id])
    raise GRPC::NotFound.new("User not found") if query_result.cmd_tuples.zero?
  
    Google::Protobuf::Empty.new
  end

  def get_private_profile(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id)

    db_query = <<~SQL
      SELECT * FROM UserPrivateProfiles WHERE id = $1
    SQL

    query_result = @db_client.query(db_query, [requester_user_id])
    raise GRPC::NotFound.new("User not found") if query_result.ntuples.zero?
  
    row = query_result.first
    UserAPIGateway::UserPrivateProfile.new(
      id:            row["id"],
      email:         row["email"],
      display_name:  row["display_name"],
      avatar:        row["avatar"] || @default_avatar,
      tfa_status:    row["tfa_status"]
      status:        row["status"]
    )
  end

  def update_profile(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id)
    raise GRPC::InvalidArgument.new("No fields to update") unless provided?(request.display_name) || provided?(request.avatar)
  
    checks = Async::Barrier.new
    result = Async do |task|

      checks.async { check_display_name(request.display_name) } if request.display_name
      if request.avatar
        checks.async { check_avatar(request.avatar) }
        avatar_task = task.async { compress_avatar(request.avatar) }
      end
  
      checks.wait
      compressed_avatar = avatar_task&.wait
  
      @db_client.transaction do |conn|

        if request.display_name
          display_name_query = <<~SQL
            UPDATE Users
            SET display_name = $1
            WHERE id = $2
            ON CONFLICT ON CONSTRAINT unq_users_display_name DO NOTHING
            RETURNING id
          SQL

          query_result = conn.exec_params(display_name_query, [request.display_name, requester_user_id])
          #TODO check e raise di display_name taken o user not found
        end

        if request.avatar
          avatar_query = <<~SQL
            UPDATE Users
            SET avatar = $1
            WHERE id = $2
          SQL

          query_result = conn.exec_params(avatar_query, [compressed_avatar, requester_user_id])
          raise GRPC::NotFound.new("User not found") if query_result.cmd_tuples.zero?
        end
      
      end
  
      Google::Protobuf::Empty.new
    end.wait
  ensure
    result&.stop
    checks&.stop
  end

  #TODO refactor da qui in giù

  def enable_tfa(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id)
    
    tfa_request  = AuthUser::Generate2FARequest.new(requester_user_id)
    tfa_response = @grpc_client.stubs[:auth].generate_tfa(tfa_request)

    query_result = @db_client.transaction do |conn|

      update_query = <<~SQL
        WITH user_check AS (
          SELECT id, tfa_status 
          FROM Users 
          WHERE id = $1
          FOR UPDATE
        )
        UPDATE Users 
        SET tfa_status = true, 
            tfa_secret = $2 
        WHERE id = $1 
          AND EXISTS (SELECT 1 FROM user_check WHERE NOT tfa_status)
        RETURNING id
      SQL

      result = conn.exec_params(update_query, [requester_user_id, tfa_response.tfa_secret])
  
      if result.cmd_tuples.zero?
        exists_query  = "SELECT 1 FROM Users WHERE id = $1"
        exists_result = conn.exec_params(exists_query, [requester_user_id])
        
        raise GRPC::NotFound.new("User not found") if exists_result.ntuples.zero?
        raise GRPC::FailedPrecondition.new("2FA is already enabled")
      end

      result
    end    

    UserAPIGateway::Enable2FAResponse.new(**tfa_response.to_h)
  end

  def get_tfa_status(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id)

    query_result = @db_client.query(
      "SELECT tfa_status FROM Users WHERE id = $1",
      [requester_user_id]
    )
    raise GRPC::NotFound.new("User not found") if query_result.ntuples.zero?
  
    UserAPIGateway::TFAStatus.new(query_result[0]['tfa_status'])
  end

  def disable_tfa(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id)
  
    query_result = @db_client.query(
      "UPDATE Users SET tfa_status = false, tfa_secret = NULL 
       WHERE id = $1 AND tfa_status = true 
       RETURNING id",
      [requester_user_id]
    )
  
    if query_result.ntuples.zero?
      exists = @db_client.query("SELECT 1 FROM Users WHERE id = $1", [requester_user_id]).ntuples > 0
      raise GRPC::NotFound.new("User not found") unless exists
      raise GRPC::FailedPrecondition.new("2FA is already disabled")
    end
  
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

      query_result = @db_client.query(
        "SELECT tfa_secret, tfa_status FROM Users WHERE id = $1",
        [requester_user_id]
      )

      raise GRPC::NotFound.new("User not found") if query_result.ntuples.zero?
      
      tfa_secret = query_result.getvalue(0, 0)
      tfa_status = query_result.getvalue(0, 1)
      raise GRPC::FailedPrecondition.new("2FA is not enabled") if tfa_secret.nil? || !tfa_status

      grpc_request  = AuthUser::Check2FACodeRequest.new(
        tfa_secret: tfa_secret,
        tfa_code:   request.tfa_code
      )

      @grpc_client.stubs[:auth].check_tfa_code(grpc_request)

      jwt_response = jwt_task.wait
      UserAPIGateway::JWT.new(jwt_response.jwt)
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

    query_result = @db_client.query(
      "SELECT id, tfa_status FROM Users WHERE email = $1 AND psw = $2",
      [request.email, hashed_password]
    )

    raise GRPC::NotFound.new("User not found") if query_result.ntuples.zero?

    user_id    = query_result.getvalue(0, 0)
    tfa_status = query_result.getvalue(0, 1)

    grpc_request = AuthUser::GenerateJWTRequest.new(
      user_id:     user_id,
      auth_level:  1,
      pending_tfa: tfa_status
    )
    grpc_response = @grpc_client.stubs[:auth].generate_jwt(grpc_request)

    UserAPIGateway::JWT.new(grpc_response.jwt)
  ensure
    barrier&.stop
  end
  
  def add_friend(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(request.requester_user_id, request.friend_user_id)

    query_result = @db_client.query(
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

    query_result = @db_client.query(
      "SELECT friend_id FROM Friendships WHERE user_id = $1 LIMIT $2 OFFSET $3",
      [requester_user_id, limit, offset]
    )

    raise GRPC::NotFound.new("No friends found") if query_result.ntuples.zero?

    friend_ids = query_result.map { |row| row["friend_id"] }

    UserAPIGateway::Friends.new(friend_ids)
  end

  def remove_friend(request, call)
    requester_user_id = call.metadata["x-requester-user-id"]
    check_required_fields(requester_user_id, request.friend_user_id)

    query_result = @db_client.query(
      "DELETE FROM Friends WHERE user_id = $1 AND friend_id = $2",
      [requester_user_id, request.friend_user_id]
    )

    raise GRPC::NotFound.new("Friend not found") if query_result.cmd_tuples.zero?

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

  def check_required_fields(*fields)
    raise GRPC::InvalidArgument.new("Missing required fields") unless fields.all?(&method(:provided?))
  end

  def provided?(field)
    field.respond_to?(:empty?) ? !field.empty? : !field.nil?
  end

end