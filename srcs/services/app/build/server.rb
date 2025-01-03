# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 14:27:54 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 18:08:28 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'falcon'
require 'openapi_first'
require 'json'
require 'async'
require_relative 'shared/config_handler'
require_relative 'shared/exceptions'
require_relative 'shared/pg_client'
require_relative 'modules/user_module'
require_relative 'modules/auth_module'

class Server

  def initialize
    @config = ConfigHandler.instance.config
    @pg_client = PGClient.instance

    @user_module = UserModule.instance
    @auth_module = AuthModule.instance

    prepare_statements
  end

  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]
    params = parsed_request.parsed_params
    operationId = parsed_request.operation['operationId']
    
    Sync { send(operationId, params, env) }
  rescue NoMethodError
    raise NotFound.new("Operation not found")
  end

  private

  def ping(params, env)
    [200, { 'Content-Type' => 'application/text' }, [{ 'pong...fu!' }]]
  end

  def registerUser(params, env)
    Async do |task|
      email, password, display_name, avatar = params.values_at(:email, :password, :display_name, :avatar)
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
      db_response = @pg_client.exec_prepared(:insert_user, [email, hashed_password, display_name, processed_avatar])
      
      body = {
        user_id: db_response.first['id']
      }
      
      [201, {}, [JSON.generate(body)]]
    end
  end

  def getUserPublicProfile(params, env)
    user_id = params[:user_id]
    check_required_fields(user_id)

    db_response = @pg_client.exec_prepared(:get_public_profile, [request.id])
    raise NotFound.new("User not found") if db_response.ntuples.zero?

    row = db_response.first  
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
    user_id = params[:user_id]
    check_required_fields(user_id)

    db_response = @pg_client.exec_prepared(:get_status, [user_id])
    raise NotFound.new("User not found") if db_response.ntuples.zero?
  
    body = {
      status: db_response.first["current_status"]
    }

    [200, {}, [JSON.generate(body)]]
  end

  def getUserMatches(params, env)
    #TODO

  def getUserTournaments(params, env)
    #TODO

  def delete_account(params, env)
    Async do |task|
      requester_user_id = env[:requester_user_id]
      check_required_fields(requester_user_id)

      task.async { @user_module.forget_past_sessions(requester_user_id) }
      task.async { @user_module.erase_user_cache(requester_user_id) }
      query_task = task.async { @pg_client.exec_prepared(:delete_user, [requester_user_id]) }
      
      query_result = query_task.wait
      raise NotFound.new("User not found") if query_result.cmd_tuples.zero?
  
      [204, {}, []]
    end
  end

  def getUserPrivateProfile(params, env)
    requester_user_id = env[:requester_user_id]
    check_required_fields(requester_user_id)

    db_response = @pg_client.exec_prepared(:get_private_profile, [requester_user_id])
    raise NotFound.new("User not found") if db_response.ntuples.zero?
  
    row = db_response.first
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
    requester_user_id = env[:requester_user_id]
    display_name, avatar = params.values_at(:display_name, :avatar)
    check_required_fields(requester_user_id)
    raise BadRequest.new("No fields to update") if params.compact.empty?
  
    @user_module.check_display_name(display_name) if display_name
    processed_avatar = if avatar
      @user_module.check_avatar(avatar)
      @user_module.compress_avatar(avatar)
    else
      nil
    end

    db_response = @pg_client.exec_prepared(:update_profile, [display_name, processed_avatar, requester_user_id])
    raise NotFound.new("User not found") if db_response.cmd_tuples.zero?

    [204, {}, []]
  end

  def enableTFA(params, env)
    Async do |task|
      requester_user_id = env[:requester_user_id]
      check_required_fields(requester_user_id)
      
      secret, provisioning_uri = @auth_module.generate_tfa_secret(requester_user_id)

      db_task = task.async { @pg_client.exec_prepared(:enable_tfa, [requester_user_id, secret]) }
      qr_code = @auth_module.generate_qr_code(provisioning_uri)
      
      db_response = db_task.wait
      raise NotFound.new("User not found") if db_response.cmd_tuples.zero?

      body = {
        tfa_secret: secret,
        tfa_qr_code: qr_code
      }
      
      [200, {}, [JSON.generate(body)]]
    end
  rescue StandardError => e
    if db_task
      db_task.stop
      @pg_client.exec_prepared(:disable_tfa, [requester_user_id]) rescue nil
    end
    raise e
  end

  def disableTFA(params, env)
    requester_user_id = env[:requester_user_id]
    tfa_code = params[:tfa_code]
    check_required_fields(requester_user_id, tfa_code)

    db_response = @pg_client.exec_prepared(:get_tfa, [requester_user_id])
    row = db_response.first
    tfa_secret = row['tfa_secret']
    tfa_status = row['tfa_status']
    raise BadRequest.new("TFA already disabled") if tfa_status == 'disabled'

    @auth_module.check_tfa_code(tfa_secret, tfa_code)

    db_response = @pg_client.exec_prepared(:delete_tfa, [requester_user_id])
    raise NotFound.new("User not found") if db_response.cmd_tuples.zero?

    [204, {}, []]
  end

  def submitTFACode(params, env)
    Async do |task|
      requester_user_id = env[:requester_user_id]
      tfa_code = params[:tfa_code]
      check_required_fields(requester_user_id, tfa_code)

      query_task = task.async { @pg_client.exec_prepared(:get_tfa, [requester_user_id]) }
      jwt_generation_task = task.async { @user_module.generate_session_jwt(requester_user_id, false) }
      forget_sessions_task = task.async { @user_module.forget_past_sessions(requester_user_id) }

      db_response = query_task.wait
      raise NotFound.new("User not found") if db_response.ntuples.zero?
    
      row = db_response.first
      tfa_secret = row['tfa_secret']
      tfa_status = row['tfa_status']
      raise BadRequest.new("TFA already disabled") if tfa_status == 'disabled'
      
      @auth_module.check_tfa_code(tfa_secret, tfa_code)

      forget_sessions_task.wait
      @pg_client.exec_prepared(:update_user_status, [requester_user_id, 'online'])

      body = {
        session_token: jwt_generation_task.wait
      }

      [200, {}, [JSON.generate(body)]]
    end
  end

  def loginUser(params, env) 
    Async do |task|
      email, password, remember_me = params.values_at(:email, :password, :remember_me)
      check_required_fields(email, password)

      query_result = @pg_client.exec_prepared(:get_login_data, [email])
      raise NotFound.new("User not found") if query_result.ntuples.zero?

      row = query_result.first
      user_id     = row["id"]
      tfa_status  = row["tfa_status"]
      hashed_psw  = row["psw"]
      user_status = row["current_status"]

      raise Unauthorized.new("User is banned") if user_status == 'banned'

      validate_password_task = task.async { @auth_module.validate_password(password, hashed_psw) }
      forget_sessions_task   = task.async { @user_module.forget_past_sessions(user_id) }
      session_jwt_task       = task.async { @user_module.generate_session_jwt(user_id, tfa_status) }
      refresh_jwt_task       = task.async { @user_module.generate_refresh_jwt(user_id, remember_me) }
  
      validate_password_task.wait
      forget_sessions_task.wait
      @pg_client.exec_prepared(:update_user_status, [user_id, 'online']) unless tfa_status
  
      body = {
        session_token: session_jwt_task.wait,
        pending_tfa: tfa_status,
      }

      headers = {
        'Set-Cookie' => @user_module.build_refresh_token_cookie_header(refresh_jwt_task.wait, remember_me)
      }

      [200, headers, [JSON.generate(body)]]
    end
  end

  def refreshUserSessionToken(params, env)
    Async do |task|
      session_token, refresh_token, requester_user_id = params.values_at(:session_token, :refresh_token, :requester_user_id)
      check_required_fields(session_token, refresh_token, requester_user_id)

      @auth_module.validate_refresh_token(refresh_token)
    
      forget_task = task.async { @user_module.forget_past_sessions(requester_user_id) }
    
      body = {
        session_token = @auth_module.extend_jwt(session_token)
      }

      forget_task.wait

      [200, {}, [JSON.generate(body)]]
    end
  end

  def logoutUser(params, env)
    Async do |task|
      requester_user_id = env[:requester_user_id]
      check_required_fields(requester_user_id)

      task.async { @user_module.forget_past_sessions(requester_user_id) }
      task.async { @pg_client.exec_prepared(:update_user_status, [requester_user_id, 'offline']) }

      [204, {}, []]
    end
  end

  def addFriend(params, env)
    requester_user_id = env[:requester_user_id]
    friend_user_id = params[:friend_user_id]
    check_required_fields(requester_user_id, friend_user_id)

    @pg_client.transaction do |tx|
      existing_request = tx.exec_prepared('check_friendship', [friend_user_id, requester_user_id])
  
      if existing_request.ntuples > 0
        status = existing_request[0]['status']
        case status
        when 'pending'
          tx.exec_prepared('update_friendship', [friend_user_id, requester_user_id, 'accepted'])
        when 'accepted'
          raise BadRequest.new("Friendship already exists")
        when 'blocked'
          break
      else
        tx.exec_prepared('insert_friend_request', [requester_user_id, friend_user_id])
      end
    end

    @grpc_client.notify_friend_request(requester_user_id, friend_user_id) #TODO implementare il metodo notify_friend_request

    [204, {}, []]
  end

  def getFriends(params, env)
    requester_user_id = env[:requester_user_id]
    check_required_fields(requester_user_id)

    limit  = params[:limit]  || 10
    offset = params[:offset] || 0
    
    query_result = @pg_client.exec_prepared(:get_friends, [requester_user_id, limit, offset])
    raise NotFound.new("User not found") if query_result.ntuples.zero?

    body = {
      friend_ids: query_result.map { |row| row['friend_id'] }
    }

    [200, {}, [JSON.generate(body)]]
  end

  def removeFriend(params, env)
    requester_user_id = env[:requester_user_id]
    friend_user_id = params[:friend_user_id]
    check_required_fields(requester_user_id, friend_user_id)
    
    query_result = @pg_client.exec_prepared(:delete_friendship, [requester_user_id, request.id])
    raise NotFound.new("Friendship not found") if query_result.cmd_tuples.zero?

    [204, {}, []]
  end

  def acceptFriendRequest(params, env)
    #TODO implementare il metodo notify_accepted_friend_request

  def rejectFriendRequest(params, env)
    #TODO

  def startMatchmaking(params, env)

  def stopMatchmaking(params, env)

  def challengeFriend(params, env)

  def getMatch(params, env)

  def leaveMatch(params, env)

  def acceptMatchInvitation(params, env)

  def declineMatchInvitation(params, env)

  def createTournament(params, env)

  def getTournament(params, env)

  def cancelTournament(params, env)

  def joinTournament(params, env)

  def leaveTournament(params, env)

  private

  def check_required_fields(*fields)
    fields.each do |field|
      raise BadRequest.new("Missing required field: #{field}") if field.nil? || field.empty?
    end
  end

end