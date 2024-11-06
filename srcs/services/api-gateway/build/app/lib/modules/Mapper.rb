# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Mapper.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:43:53 by craimond          #+#    #+#              #
#    Updated: 2024/11/06 21:04:04 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../proto/users_services_pb'
require_relative '../proto/match_services_pb'
require_relative '../proto/tournament_services_pb'
require_relative './modules/Structs'

module Mapper

  #TODO gestire casi di serialization di path_params, query_params, headers
  def self.map_request_to_grpc_request(request, operation_id, requesting_user_id)
    case operation_id
    when "registerUser"
      UserService::RegisterUserRequest.new(
        requesting_user_id: requesting_user_id,
        email: request[:body]["email"],
        password: request[:body]["password"],
        display_name: request[:body]["display_name"],
        avatar: request[:body]["avatar"] )
    when "getUserProfile"
      UserService::GetUserProfileRequest.new(
        requesting_user_id: requesting_user_id,
        user_id: request[:path_params]["user_id"],
        etag: request[:headers]["if-none-match"] )
    when "getUserStatus"
      UserService::GetUserStatusRequest.new(
        requesting_user_id: requesting_user_id,
        user_id: request[:path_params]["user_id"] )
    when "getUserMatches"
      MatchService::GetUserMatchesRequest.new(
        requesting_user_id: requesting_user_id,
        user_id: request[:path_params]["user_id"],
        limit: request[:query_params]["limit"],
        offset: request[:query_params]["offset"],
        sort_by: request[:query_params]["sort_by"],
        filters: MatchService::player_match_filters.new(
          status: request[:query_params]["filters"]["status"]
        ).compact if request[:query_params]["filters"],
        etag: request[:headers]["if-none-match"] )
    when "getUserTournaments"
      TournamentService::GetUserTournamentsRequest.new(
        requesting_user_id: requesting_user_id,
        user_id: request[:path_params]["user_id"],
        limit: request[:query_params]["limit"],
        offset: request[:query_params]["offset"],
        sort_by: request[:query_params]["sort_by"],
        filters: TournamentService::PlayerTournamentFilters.new(
          mode: request[:query_params]["filters"]["mode"],
          status: request[:query_params]["filters"]["status"]
        ).compact if request[:query_params]["filters"],
        etag: request[:headers]["if-none-match"] )
    when "deleteAccount"
      UserService::DeleteAccountRequest.new(
        requesting_user_id: requesting_user_id, )
    when "getPrivateProfile"
      UserService::GetPrivateProfileRequest.new(
        requesting_user_id: requesting_user_id,
        etag: request[:headers]["if-none-match"] )
    when "updateProfile"
      UserService::UpdateProfileRequest.new(
        requesting_user_id: requesting_user_id,
        display_name: request[:body]["display_name"],
        avatar: request[:body]["avatar"] )
    when "updatePassword"
      UserService::UpdatePasswordRequest.new(
        requesting_user_id: requesting_user_id,
        old_password: request[:body]["old_password"],
        new_password: request[:body]["new_password"] )
    when "requestPasswordReset"
      UserService::RequestPasswordResetRequest.new(
        email: request[:body]["email"] )
    when "checkPasswordResetToken"
      UserService::CheckPasswordResetTokenRequest.new(
        token: request[:path_params]["token"] )
    when "resetPassword"
      UserService::ResetPasswordRequest.new(
        token: request[:path_params]["token"],
        new_password: request[:body]["new_password"], )
    when "updateEmail"
      UserService::UpdateEmailRequest.new(
        requesting_user_id: requesting_user_id,
        new_email: request[:body]["new_email"],
        current_password: request[:body]["current_password"],
        totp_code: request[:body]["totp_code"] )
    when "verifyEmail"
      UserService::VerifyEmailRequest.new(
        requesting_user_id: requesting_user_id )
    when "checkEmailVerificationToken"
      UserService::CheckEmailVerificationTokenRequest.new(
        token: request[:path_params]["token"] )
    when "enable2FA"
      UserService::Enable2FARequest.new(
        requesting_user_id: requesting_user_id )
    when "get2FAStatus"
      UserService::Get2FAStatusRequest.new(
        requesting_user_id: requesting_user_id )
    when "disable2FA"
      UserService::Disable2FARequest.new(
        requesting_user_id: requesting_user_id )
    when "check2FACode"
      UserService::Check2FACodeRequest.new(
        requesting_user_id: requesting_user_id,
        totp_code: request[:body]["totp_code"] )
    when "loginUser"
      UserService::LoginUserRequest.new(
        email: request[:body]["email"],
        password: request[:body]["password"],
        totp_code: request[:body]["totp_code"] )
    when "logoutUser"
      UserService::LogoutUserRequest.new(
        requesting_user_id: requesting_user_id )
    when "addFriend"
      UserService::AddFriendRequest.new(
        requesting_user_id: requesting_user_id,
        friend_id: request[:body]["friend_id"] )
    when "getFriends"
      UserService::GetFriendsRequest.new(
        requesting_user_id: requesting_user_id,
        limit: request[:query_params]["limit"],
        offset: request[:query_params]["offset"],
        sort_by: request[:query_params]["sort_by"],
        filters: UserService::ProfileFilters.new(
          status: request[:query_params]["filters"]["status"]
        ).compact if request[:query_params]["filters"],
        etag: request[:headers]["if-none-match"] )
    when "removeFriend"
      UserService::RemoveFriendRequest.new(
        requesting_user_id: requesting_user_id,
        friend_id: request[:path_params]["friend_id"] )
    when "createMatch"
      MatchService::CreateMatchRequest.new(
        requesting_user_id: requesting_user_id,
        invited_user_ids: request[:body]["invited_user_ids"],
        settings: MatchService::MatchSettings.new(
          ball_speed: request[:body]["settings"]["ball_speed"],
          max_duration: request[:body]["settings"]["max_duration"],
          starting_health: request[:body]["settings"]["starting_health"] ) if request[:body]["settings"] )
    when "joinMatch"
      MatchService::JoinMatchRequest.new(
        requesting_user_id: requesting_user_id,
        match_id: request[:path_params]["match_id"] )
    when "getMatch"
      MatchService::GetMatchRequest.new(
        requesting_user_id: requesting_user_id,
        match_id: request[:path_params]["match_id"],
        etag: request[:headers]["if-none-match"] )
    when "leaveMatch"
      MatchService::LeaveMatchRequest.new(
        requesting_user_id: requesting_user_id,
        match_id: request[:path_params]["match_id"] )
    when "createTournament"
      TournamentService::CreateTournamentRequest.new(
        requesting_user_id: requesting_user_id,
        invited_user_ids: request[:body]["invited_user_ids"],
        mode: TOURNAMENT_MODES_STRING_TO_ENUM_MAP[request[:body]["mode"]] )
    when "joinTournament"
      TournamentService::JoinTournamentRequest.new(
        requesting_user_id: requesting_user_id,
        tournament_id: request[:path_params]["tournament_id"] )
    when "getTournament"
      TournamentService::GetTournamentRequest.new(
        requesting_user_id: requesting_user_id,
        tournament_id: request[:path_params]["tournament_id"],
        etag: request[:headers]["if-none-match"] )
    when "leaveTournament"
      TournamentService::LeaveTournamentRequest.new(
        requesting_user_id: requesting_user_id,
        tournament_id: request[:path_params]["tournament_id"] )
    else
      raise ActionFailedException::NotImplemented
    end
  end

  #NOTE: Rate limiting headers are added later on a client-basis in the ClientHandler
  def self.map_grpc_response_to_response(grpc_response, operation_id)
    case operation_id
    when "registerUser"
      status_code = grpc_response.status_code
      user_id = grpc_response.user_id
      body = { user_id: user_id } if user_id
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s if body,
        "Cache-Control" => "private" if body,
      }.compact
    
      Response.new(status_code, headers, body)    
    when "getUserProfile"
      status_code = grpc_response.status_code
      user = grpc_response.user
      body = {
        user_id: user.user_id,
        display_name: user.display_name,
        avatar: user.avatar,
        status: user.status,
        last_active_timestamp: user.last_active_timestamp,
        registered_timestamp: user.registered_timestamp,
      }.compact if user
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s if body,
        "Cache-Control" => "public, max-age=1800" if body,
        "ETag" => grpc_response.etag if body
      }.compact
    
      Response.new(status_code, headers, body)    
    when "getUserStatus"
      status_code = grpc_response.status_code
      status = grpc_response.status
      body = { status: status } if status
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s if body,
        "Cache-Control" => "public, max-age=300" if body
      }.compact
    
      Response.new(status_code, headers, body)    
    when "getUserMatches"
      status_code = grpc_response.status_code
      matches = grpc_response.matches || []
      body = matches.map do |match|
        {
          id: match.id,
          player_ids: match.player_ids,
          status: match.status,
          started_timestamp: match.started_timestamp,
          finished_timestamp: match.finished_timestamp,
          settings: {
            ball_speed: match.settings.ball_speed,
            max_duration: match.settings.max_duration,
            starting_health: match.settings.starting_health,
          }.compact
        }.compact
      end.presence || nil
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s if body,
        "Cache-Control" => "public, max-age=300" if body,
        "ETag" => grpc_response.etag if body
      }.compact
    
      Response.new(status_code, headers, body)    
    when "getUserTournaments"
      status_code = grpc_response.status_code
      tournaments = grpc_response.tournaments || []
      body = tournaments.map do |tournament|
        {
          id: tournament.id,
          mode: TOURNAMENT_MODES_ENUM_TO_STRING_MAP[tournament.mode],
          match_ids: tournament.match_ids,
          status: tournament.status,
          started_timestamp: tournament.started_timestamp,
          finished_timestamp: tournament.finished_timestamp,
        }.compact
      end.presence || nil
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s if body,
        "Cache-Control" => "public, max-age=300" if body,
        "ETag" => grpc_response.etag if body
      }.compact
    
      Response.new(status_code, headers, body)
    when "deleteAccount"
      status_code = grpc_response.status_code
      body = nil
      headers = {}

      Response.new(status_code, headers, body)
    when "getPrivateProfile"
      status_code = grpc_response.status_code
      user = grpc_response.user
      body = {
        id: user.id,
        display_name: user.display_name,
        avatar: user.avatar,
        status: user.status,
        last_active_timestamp: user.last_active_timestamp,
        registered_timestamp: user.registered_timestamp,
        email: user.email,
        two_factor_auth_enabled: user.two_factor_auth_enabled
      }.compact if user
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s if body,
        "Cache-Control" => "private, must-revalidate" if body,
        "ETag" => grpc_response.etag if body
      }.compact

      Response.new(status_code, headers, body)
    when "updateProfile"
      Response.new(grpc_response.status_code, {}, nil)
    when "updatePassword"
      Response.new(grpc_response.status_code, {}, nil)
    when "requestPasswordReset"
      Response.new(grpc_response.status_code, {}, nil)
    when "checkPasswordResetToken"
      Response.new(grpc_response.status_code, {}, nil)
    when "resetPassword"
      Response.new(grpc_response.status_code, {}, nil)
    when "updateEmail"
      Response.new(grpc_response.status_code, {}, nil)
    when "verifyEmail"
      Response.new(grpc_response.status_code, {}, nil)
    when "checkEmailVerificationToken"
      Response.new(grpc_response.status_code, {}, nil)
    when "enable2FA"
      status_code = grpc_response.status_code
      totp_secret = grpc_response.totp_secret
      body = { totp_secret: totp_secret } if totp_secret
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s if body,
        "Cache-Control" => "no-store" if body
      }.compact

      Response.new(status_code, headers, body)
    when "get2FAStatus"
      status_code = grpc_response.status_code
      two_factor_auth_enabled = grpc_response.two_factor_auth_enabled
      body = { two_factor_auth_enabled: two_factor_auth_enabled } if two_factor_auth_enabled
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s if body,
        "Cache-Control" => "private, no-cache" if body
      }.compact

      Response.new(status_code, headers, body)
    when "disable2FA"
      Response.new(grpc_response.status_code, {}, nil)
    when "check2FACode"
      Response.new(grpc_response.status_code, {}, nil)
    when "loginUser"
      status_code = grpc_response.status_code
      jwt_token = grpc_response.jwt_token
      body = { jwt_token: jwt_token } if jwt_token
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s if body,
        "Cache-Control" => "no-store" if body
      }.compact

      Response.new(status_code, headers, body)
    when "logoutUser"
      Response.new(grpc_response.status_code, {}, nil)
    when "addFriend"
      Response.new(grpc_response.status_code, {}, nil)
    when "getFriends"
      status_code = grpc_response.status_code
      friend_ids = grpc_response.friend_ids
      body = { friend_ids: friend_ids } if friend_ids
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s if body,
        "Cache-Control" => "private, max-age=300" if body
        "ETag" => grpc_response.etag if body
      }.compact

      Response.new(status_code, headers, body)
    when "removeFriend"
      Response.new(grpc_response.status_code, {}, nil)
    else
      raise ActionFailedException::NotImplemented
    end
  end
    
end
