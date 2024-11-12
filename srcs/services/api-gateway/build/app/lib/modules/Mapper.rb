# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Mapper.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:43:53 by craimond          #+#    #+#              #
#    Updated: 2024/11/09 20:09:51 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require_relative "../proto/user_service_pb"
require_relative "../proto/match_service_pb"
require_relative "../proto/tournament_service_pb"
require_relative "./modules/Structs"

module Mapper

  EXCEPTIONS_TO_STATUS_CODE_MAP = {
    ActionFailedException::BadRequest          => 400,
    ActionFailedException::Unauthorized        => 401,
    ActionFailedException::Forbidden           => 403,
    ActionFailedException::NotFound            => 404,
    ActionFailedException::MethodNotAllowed    => 405,
    ActionFailedException::RequestTimeout      => 408,
    ActionFailedException::Conflict            => 409,
    ActionFailedException::URITooLong          => 414,
    ActionFailedException::TooManyRequests     => 429,
    ActionFailedException::InternalServer      => 500,
    ActionFailedException::NotImplemented      => 501,
    ActionFailedException::BadGateway          => 502,
    ActionFailedException::ServiceUnavailable  => 503,
    ActionFailedException::GatewayTimeout      => 504
  }.freeze

  STATUS_CODE_TO_MESSAGE_MAP = {
    200 => "OK",
    201 => "Created",
    204 => "No Content",
    304 => "Not Modified",
    400 => "Bad Request",
    401 => "Unauthorized",
    403 => "Forbidden",
    404 => "Not Found",
    405 => "Method Not Allowed",
    408 => "Request Timeout",
    409 => "Conflict",
    414 => "URI Too Long",
    429 => "Too Many Requests",
    500 => "Internal Server Error",
    501 => "Not Implemented",
    502 => "Bad Gateway",
    503 => "Service Unavailable",
    504 => "Gateway Timeout"
  }.freeze

  def self.map_request_to_grpc_request(request, operation_id, requesting_user_id)
    case operation_id
    when "registerUser"
      UserService::RegisterUserRequest.new(
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
      status_code = grpc_response.status_code || 500
      return Response.new(status_code, {}, nil) if status_code >= 400

      user_id = grpc_response.user_id
      body = { user_id: user_id }
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s,
        "Cache-Control" => "private",
      }.compact
    
      Response.new(status_code, headers, body)    
    when "getUserProfile"
      status_code = grpc_response.status_code || 500
      return Response.new(status_code, {}, nil) if status_code >= 400

      user = grpc_response.user
      body = {
        user_id: user.user_id,
        display_name: user.display_name,
        avatar: user.avatar,
        status: user.status,
        last_active_timestamp: user.last_active_timestamp,
        registered_timestamp: user.registered_timestamp,
      }.compact
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s,
        "Cache-Control" => "public, max-age=1800",
        "ETag" => grpc_response.etag
      }.compact
    
      Response.new(status_code, headers, body)    
    when "getUserStatus"
      status_code = grpc_response.status_code || 500
      return Response.new(status_code, {}, nil) if status_code >= 400

      status = grpc_response.status
      body = { status: status }
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s,
        "Cache-Control" => "public, max-age=300"
      }.compact
    
      Response.new(status_code, headers, body)    
    when "getUserMatches"
      status_code = grpc_response.status_code || 500
      return Response.new(status_code, {}, nil) if status_code >= 400

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
        "Content-Length" => body.to_json.bytesize.to_s,
        "Cache-Control" => "public, max-age=300",
        "ETag" => grpc_response.etag
      }.compact
    
      Response.new(status_code, headers, body)    
    when "getUserTournaments"
      status_code = grpc_response.status_code || 500
      return Response.new(status_code, {}, nil) if status_code >= 400

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
        "Content-Length" => body.to_json.bytesize.to_s,
        "Cache-Control" => "public, max-age=300",
        "ETag" => grpc_response.etag
      }.compact
    
      Response.new(status_code, headers, body)
    when "deleteAccount"
      status_code = grpc_response.status_code || 500
      Response.new(status_code, {}, nil)
    when "getPrivateProfile"
      status_code = grpc_response.status_code || 500
      return Response.new(status_code, {}, nil) if status_code >= 400

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
      }.compact
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s,
        "Cache-Control" => "private, must-revalidate",
        "ETag" => grpc_response.etag
      }.compact

      Response.new(status_code, headers, body)
    when "updateProfile"
      status_code = grpc_response.status_code || 500
      Response.new(status_code, {}, nil)
    when "updatePassword"
      status_code = grpc_response.status_code || 500
      Response.new(status_code, {}, nil)
    when "requestPasswordReset"
      status_code = grpc_response.status_code || 500
      Response.new(status_code, {}, nil)
    when "checkPasswordResetToken"
      status_code = grpc_response.status_code || 500
      Response.new(status_code, {}, nil)
    when "resetPassword"
      status_code = grpc_response.status_code || 500
      Response.new(status_code, {}, nil)
    when "updateEmail"
      status_code = grpc_response.status_code || 500
      Response.new(status_code, {}, nil)
    when "verifyEmail"
      status_code = grpc_response.status_code || 500
      Response.new(status_code, {}, nil)
    when "checkEmailVerificationToken"
      status_code = grpc_response.status_code || 500
      Response.new(status_code, {}, nil)
    when "enable2FA"
      status_code = grpc_response.status_code || 500
      return Response.new(status_code, {}, nil) if status_code >= 400

      totp_secret = grpc_response.totp_secret
      body = { totp_secret: totp_secret }
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s,
        "Cache-Control" => "no-store"
      }.compact

      Response.new(status_code, headers, body)
    when "get2FAStatus"
      status_code = grpc_response.status_code || 500
      return Response.new(status_code, {}, nil) if status_code >= 400

      two_factor_auth_enabled = grpc_response.two_factor_auth_enabled
      body = { two_factor_auth_enabled: two_factor_auth_enabled } if two_factor_auth_enabled
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s,
        "Cache-Control" => "private, no-cache"
      }.compact

      Response.new(status_code, headers, body)
    when "disable2FA"
      status_code = grpc_response.status_code || 500
      Response.new(status_code, {}, nil)
    when "check2FACode"
      status_code = grpc_response.status_code || 500
      Response.new(status_code, {}, nil)
    when "loginUser"
      status_code = grpc_response.status_code || 500
      return Response.new(status_code, {}, nil) if status_code >= 400

      jwt_token = grpc_response.jwt_token
      body = { jwt_token: jwt_token }
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s,
        "Cache-Control" => "no-store"
      }.compact

      Response.new(status_code, headers, body)
    when "logoutUser"
      status_code = grpc_response.status_code || 500
      Response.new(status_code, {}, nil)
    when "addFriend"
      status_code = grpc_response.status_code || 500
      Response.new(status_code, {}, nil)
    when "getFriends"
      status_code = grpc_response.status_code || 500
      return Response.new(status_code, {}, nil) if status_code >= 400

      friend_ids = grpc_response.friend_ids
      body = { friend_ids: friend_ids }
      headers = {
        "Content-Length" => body.to_json.bytesize.to_s,
        "Cache-Control" => "private, max-age=300"
        "ETag" => grpc_response.etag
      }.compact

      Response.new(status_code, headers, body)
    when "removeFriend"
      status_code = grpc_response.status_code || 500
      Response.new(status_code, {}, nil)
    else
      raise ActionFailedException::NotImplemented
    end
  end
    
end
