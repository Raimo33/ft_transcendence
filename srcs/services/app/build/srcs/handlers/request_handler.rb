# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 14:27:54 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 14:20:50 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'openapi_first'
require 'json'
require 'async'
require_relative 'shared/config_handler'
require_relative 'shared/exceptions'
require_relative 'shared/pg_client'
require_relative 'shared/grpc_client'
require_relative 'shared/request_context'
require_relative 'modules/user_module'
require_relative 'modules/auth_module'
require_relative 'modules/match_module'
require_relative 'modules/matchmaking_module'

class RequestHandler

  def initialize
    @config = ConfigHandler.instance.config
    @pg_client = PGClient.instance
    @grpc_client = GrpcClient.instance

    @user_module = UserModule.instance
    @auth_module = AuthModule.instance
    @match_module = MatchModule.instance
    @matchmaking_module = MatchmakingModule.instance

    prepare_statements
  end

  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]
    params = parsed_request.parsed_params
    operation_id = parsed_request.operation["operationId"]
    
    Sync { send(operation_id, params, env) }
  rescue NoMethodError
    raise NotFound.new("Operation not found")
  end

  private

  def ping(params, env)
    [200, { "Content-Type" => "application/text" }, [{ "pong...fu!" }]]
  end

  def registerUser(params, env)
    Async do |task|
      email, password, display_name, avatar = params.values_at("email", "password", "display_name", "avatar")
      check_required_fields(email, password, display_name)

      email_task = task.async { @user_module.check_email(email) }
      @user_module.check_password(password)
      @user_module.check_display_name(display_name)

      processed_avatar = if avatar
        @user_module.check_avatar(avatar)
        @user_module.compress_avatar(avatar)
      else
        nil
      end
      hashed_password = @auth_module.hash_password(password)

      email_task.wait
      query_result = @pg_client.exec_prepared(:insert_user, [email, hashed_password, display_name, processed_avatar])
      
      body = {
        user_id: query_result.first["id"]
      }
      
      [201, {}, [JSON.generate(body)]]
    end
  end

  def getUserPublicProfile(params, env)
    user_id = params["user_id"]
    check_required_fields(user_id)

    query_result = @pg_client.exec_prepared(:get_public_profile, [request.id])
    raise NotFound.new("User not found") if query_result.ntuples.zero?

    row = query_result.first  
    body = {
      user_id:      row["id"],
      display_name: row["display_name"],
      avatar:       row["avatar"] || @user_module.default_avatar,
      status:       row["current_status"],
      created_at:   row["created_at"]
    }

    [200, {}, [JSON.generate(body)]]
  end

  def getUserStatus(params, env)
    user_id = params["user_id"]
    check_required_fields(user_id)

    query_result = @pg_client.exec_prepared(:get_status, [user_id])
    raise NotFound.new("User not found") if query_result.ntuples.zero?
  
    body = {
      status: query_result.first["current_status"]
    }

    [200, {}, [JSON.generate(body)]]
  end

  def getUserMatches(params, env)
    user_id, cursor, limit = params.values_at("user_id", "cursor", "limit")
    check_required_fields(user_id)

    cursor = if provided?(cursor)
      decode_cursor(cursor)
    else
      nil
    end

    started_at_str, match_id_str = cursor&.split(',')
    started_at = started_at_str ? Time.parse(started_at_str) : Time.now
    match_id = match_id_str
    limit ||= 10

    result = @pg_client.exec_prepared(:get_user_matches, [user_id, started_at, match_id, limit])

    last_row = result.last
    body = {
      match_ids: result.map { |row| row["match_id"] },
      cursor: encode_cursor(last_row["started_at"], last_row["match_id"])
    }

    [200, {}, [JSON.generate(body)]]
  end

  def getUserTournaments(params, env)
    #TODO

  def deleteUser(params, env)
    Async do |task|
      user_id = RequestContext.requester_user_id
      check_required_fields(user_id)

      task.async { @user_module.forget_past_sessions(user_id) }
      task.async { @user_module.erase_user_cache(user_id) }
      query_task = task.async { @pg_client.exec_prepared(:delete_user, [user_id]) }
      
      query_result = query_task.wait
      raise NotFound.new("User not found") if query_result.cmd_tuples.zero?
  
      [204, {}, []]
    end
  end

  def getUserPrivateProfile(params, env)
    user_id = RequestContext.requester_user_id
    check_required_fields(user_id)

    query_result = @pg_client.exec_prepared(:get_private_profile, [user_id])
    raise NotFound.new("User not found") if query_result.ntuples.zero?
  
    row = query_result.first
    body = {
      id:            row["id"],
      email:         row["email"],
      display_name:  row["display_name"],
      avatar:        row["avatar"] || @user_module.default_avatar,
      tfa_status:    row["tfa_status"],
      status:        row["current_status"],
      created_at:    row["created_at"]
    }

    [200, {}, [JSON.generate(body)]]
  end

  def updateProfile(params, env)
    user_id = RequestContext.requester_user_id
    display_name, avatar = params.values_at("display_name", "avatar")
    check_required_fields(user_id)
    raise BadRequest.new("No fields to update") if params.compact.empty?
  
    @user_module.check_display_name(display_name) if display_name
    processed_avatar = if avatar
      @user_module.check_avatar(avatar)
      @user_module.compress_avatar(avatar)
    else
      nil
    end

    query_result = @pg_client.exec_prepared(:update_profile, [display_name, processed_avatar, user_id])
    raise NotFound.new("User not found") if query_result.cmd_tuples.zero?

    [204, {}, []]
  end

  def enableTFA(params, env)
    Async do |task|
      user_id = RequestContext.requester_user_id
      check_required_fields(user_id)
      
      secret, provisioning_uri = @auth_module.generate_tfa_secret(user_id)

      db_task = task.async { @pg_client.exec_prepared(:enable_tfa, [user_id, secret]) }
      qr_code = @auth_module.generate_qr_code(provisioning_uri)
      
      query_result = db_task.wait
      raise NotFound.new("User not found") if query_result.cmd_tuples.zero?

      body = {
        tfa_secret: secret,
        tfa_qr_code: qr_code
      }
      
      [200, {}, [JSON.generate(body)]]
    end
  rescue
    if db_task
      db_task.stop
      @pg_client.exec_prepared(:disable_tfa, [user_id]) rescue nil
    end
    raise
  end

  def disableTFA(params, env)
    user_id = RequestContext.requester_user_id
    tfa_code = params["tfa_code"]
    check_required_fields(user_id, tfa_code)

    query_result = @pg_client.exec_prepared(:get_tfa, [user_id])
    row = query_result.first
    tfa_secret = row["tfa_secret"]
    tfa_status = row["tfa_status"]
    raise BadRequest.new("TFA already disabled") if tfa_status == "disabled"

    @auth_module.check_tfa_code(tfa_secret, tfa_code)

    query_result = @pg_client.exec_prepared(:delete_tfa, [user_id])
    raise NotFound.new("User not found") if query_result.cmd_tuples.zero?

    [204, {}, []]
  end

  def submitTFACode(params, env)
    Async do |task|
      user_id = RequestContext.requester_user_id
      tfa_code = params["tfa_code"]
      check_required_fields(user_id, tfa_code)

      query_task = task.async { @pg_client.exec_prepared(:get_tfa, [user_id]) }
      jwt_generation_task = task.async { @user_module.generate_session_jwt(user_id, false) }
      forget_sessions_task = task.async { @user_module.forget_past_sessions(user_id) }

      query_result = query_task.wait
      raise NotFound.new("User not found") if query_result.ntuples.zero?
    
      row = query_result.first
      tfa_secret = row["tfa_secret"]
      tfa_status = row["tfa_status"]
      raise BadRequest.new("TFA already disabled") if tfa_status == "disabled"
      
      @auth_module.check_tfa_code(tfa_secret, tfa_code)

      forget_sessions_task.wait
      @pg_client.exec_prepared(:update_user_status, [user_id, "online"])

      body = {
        session_token: jwt_generation_task.wait
      }

      [200, {}, [JSON.generate(body)]]
    end
  end

  def loginUser(params, env) 
    Async do |task|
      email, password, remember_me = params.values_at("email", "password", "remember_me")
      check_required_fields(email, password)

      query_result = @pg_client.exec_prepared(:get_login_data, [email])
      raise NotFound.new("User not found") if query_result.ntuples.zero?

      row = query_result.first
      user_id     = row["id"]
      tfa_status  = row["tfa_status"]
      hashed_psw  = row["psw"]
      user_status = row["current_status"]

      raise Unauthorized.new("User is banned") if user_status == "banned"

      validate_password_task = task.async { @auth_module.validate_password(password, hashed_psw) }
      forget_sessions_task   = task.async { @user_module.forget_past_sessions(user_id) }
      session_jwt_task       = task.async { @user_module.generate_session_jwt(user_id, tfa_status) }
      refresh_jwt_task       = task.async { @user_module.generate_refresh_jwt(user_id, remember_me) }
  
      validate_password_task.wait
      forget_sessions_task.wait
      @pg_client.exec_prepared(:update_user_status, [user_id, "online"]) unless tfa_status
  
      body = {
        session_token: session_jwt_task.wait,
        pending_tfa: tfa_status,
      }

      headers = {
        "Set-Cookie" => @user_module.build_refresh_token_cookie_header(refresh_jwt_task.wait, remember_me)
      }

      [200, headers, [JSON.generate(body)]]
    end
  end

  def refreshUserSessionToken(params, env)
    Async do |task|
      session_token = RequestContext.session_token
      refresh_token = RequestContext.refresh_token
      user_id = RequestContext.requester_user_id
      check_required_fields(session_token, refresh_token, user_id)

      @auth_module.validate_refresh_token(refresh_token)
    
      forget_task = task.async { @user_module.forget_past_sessions(user_id) }
    
      body = {
        session_token = @auth_module.extend_jwt(session_token)
      }

      forget_task.wait

      [200, {}, [JSON.generate(body)]]
    end
  end

  def logoutUser(params, env)
    Async do |task|
      user_id = RequestContext.requester_user_id
      check_required_fields(user_id)

      task.async { @user_module.forget_past_sessions(user_id) }
      task.async { @pg_client.exec_prepared(:update_user_status, [user_id, "offline"]) }

      [204, {}, []]
    end
  end

  def addFriend(params, env)
    user_id = RequestContext.requester_user_id
    friend_id = params["friend_id"]
    check_required_fields(user_id, friend_id)

    @pg_client.transaction do |tx|
      existing_request = tx.exec_prepared("check_friendship", [friend_id, user_id])
  
      if existing_request.ntuples > 0
        status = existing_request[0]["status"]
        case status
        when "pending"
          tx.exec_prepared("update_friendship", [friend_id, user_id, "accepted"])
        when "accepted"
          raise BadRequest.new("Friendship already exists")
        when "blocked"
          break
      else
        tx.exec_prepared("insert_friend_request", [user_id, friend_id])
      end
    end

    @grpc_client.notify_friend_request(user_id, friend_id)

    [204, {}, []]
  end

  def getFriends(params, env)
    user_id = RequestContext.requester_user_id
    limit, cursor = params.values_at("limit", "cursor")
    check_required_fields(user_id)

    cursor = if provided?(cursor)
      decode_cursor(cursor)
    else
      nil
    end

    last_created_at_str, last_friend_id_str = cursor&.split(',')
    last_created_at = last_created_at_str ? Time.parse(last_created_at_str) : Time.now
    last_friend_id = last_friend_id_str
    limit ||= 10
    
    query_result = @pg_client.exec_prepared(:get_friends, [user_id, last_created_at, last_friend_id, limit])
    raise NotFound.new("User not found") if query_result.ntuples.zero?

    last_row = query_result.last
    body = {
      friend_ids: query_result.map { |row| row["friend_id"] }
      cursor: encode_cursor(last_row["created_at"], last_row["friend_id"])
    }

    [200, {}, [JSON.generate(body)]]
  end

  def removeFriend(params, env)
    user_id = RequestContext.requester_user_id
    friend_id = params["friend_id"]
    check_required_fields(user_id, friend_id)
    
    query_result = @pg_client.exec_prepared(:delete_friendship, [user_id, request.id])
    raise NotFound.new("Friendship not found") if query_result.cmd_tuples.zero?

    [204, {}, []]
  end

  def acceptFriendRequest(params, env)
    Async do |task|
      user_id = RequestContext.requester_user_id
      friend_id = params["friend_id"]
      check_required_fields(user_id, friend_id)

      db_task = task.async { @pg_client.exec_prepared(:update_friendship, [friend_id, user_id, 'accepted']) }
      notification_task = task.async { @grpc_client.notify_friend_request_accepted(user_id, friend_id) }

      query_result = db_task.wait
      raise NotFound.new("Friendship not found") if query_result.cmd_tuples.zero?

      [204, {}, []]
    end
  end

  def rejectFriendRequest(params, env)
    user_id = RequestContext.requester_user_id
    friend_id = params["friend_id"]
    check_required_fields(user_id, friend_id)

    query_result = @pg_client.exec_prepared(:delete_friendship, [friend_id, user_id])
    raise NotFound.new("Friendship not found") if query_result.cmd_tuples.zero?

    [204, {}, []]
  end

  def startMatchmaking(params, env)
    user_id = RequestContext.requester_user_id
    check_required_fields(user_id)

    response = @pg_client.exec_prepared(:is_playing, [user_id])
    is_playing = response.first["is_playing"] == 't'
    raise BadRequest.new("User is already playing") if is_playing

    @matchmaking_module.add_matchmaking_user(user_id)

    [204, {}, []]
  end

  def stopMatchmaking(params, env)
    user_id = RequestContext.requester_user_id
    check_required_fields(user_id)

    @matchmaking_module.remove_matchmaking_user(user_id)

    [204, {}, []]
  end

  def challengeFriend(params, env)
    user_id = RequestContext.requester_user_id
    friend_id = params["friend_id"]
    check_required_fields(user_id, friend_id)

    @matchmaking_module.add_match_invitation(user_id, friend_id)

    [204, {}, []]
  end

  def getMatch(params, env)
    match_id = params["match_id"]
    check_required_fields(match_id)

    query_result = @pg_client.exec_prepared(:get_match_info, [match_id])
    raise NotFound.new("Match not found") if query_result.ntuples.zero?

    row = query_result.first
    body = {
      id:            row["id"],
      player_ids:    row["player_ids"],
      status:        row["current_status"],
      started_at:    row["started_at"],
      ended_at:      row["ended_at"]
      tournament_id: row["tournament_id"]
    }

    [200, {}, [JSON.generate(body)]]
  end

  def acceptMatchInvitation(params, env)
    Async do |task|
      user_id = RequestContext.requester_user_id
      friend_id = params["friend_id"]
      check_required_fields(user_id, friend_id)

      match_id = SecureRandom.uuid
    
      task.async { @matchmaking_module.remove_match_invitation(friend_id, user_id) }

      task.async do
        @pg_client.transaction do |tx|
          tx.exec_prepared(:insert_match, [match_id])
          tx.exec_prepared(:insert_match_players, [match_id, user_id, friend_id])
        end
      end

      task.async { @grpc_client.setup_match_state(match_id, user_id, friend_id) }
      
      @grpc_client.notify_match_found(match_id, user_id, friend_id)
    end
  rescue
    Async do |task|
      task.async { @matchmaking_module.remove_match_invitation(friend_id, user_id) }
      task.async { @pg_client.exec_prepared(:delete_match, [match_id]) }
      task.async { @grpc_client.close_match_state(match_id) }
    end.wait rescue nil
    raise
  end

  def declineMatchInvitation(params, env)
    user_id = RequestContext.requester_user_id
    friend_id = params["friend_id"]
    check_required_fields(user_id, friend_id)

    @matchmaking_module.remove_match_invitation(friend_id, user_id)

    [204, {}, []]
  end

  def createTournament(params, env)

  def getTournament(params, env)

  def cancelTournament(params, env)

  def joinTournament(params, env)

  def leaveTournament(params, env)
    #TODO wont work if user is in match (prevenzione di bug)

  private

  def check_required_fields(*fields)
    fields.each do |field|
      raise BadRequest.new("Missing required field: #{field}") if field.nil? || field.empty?
    end
  end

  def encode_cursor(*fields)
    fields.join(',')
  end

  def decode_cursor(cursor)
    cursor.split(',')
  end

end