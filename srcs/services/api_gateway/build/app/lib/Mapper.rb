# # **************************************************************************** #
# #                                                                              #
# #                                                         :::      ::::::::    #
# #    Mapper.rb                                          :+:      :+:    :+:    #
# #                                                     +:+ +:+         +:+      #
# #    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
# #                                                 +#+#+#+#+#+   +#+            #
# #    Created: 2024/10/29 14:43:53 by craimond          #+#    #+#              #
# #    Updated: 2024/11/17 16:49:48 by craimond         ###   ########.fr        #
# #                                                                              #
# # **************************************************************************** #

# require "grpc"
# require_relative "../proto/user_api_gateway_service_pb"
# require_relative "../proto/match_api_gateway_service_pb"
# require_relative "../proto/tournament_api_gateway_service_pb"
# require_relative "./modules/Structs"

module Mapper

  EXCEPTIONS_TO_STATUS_CODE_MAP = {
    ActionFailedException::BadRequest          => 400,
    ActionFailedException::Unauthorized        => 401,
    ActionFailedException::Forbidden           => 403,
    ActionFailedException::NotFound            => 404,
    ActionFailedException::MethodNotAllowed    => 405,
    ActionFailedException::RequestTimeout      => 408,
    ActionFailedException::Conflict            => 409,
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
    429 => "Too Many Requests",
    500 => "Internal Server Error",
    501 => "Not Implemented",
    502 => "Bad Gateway",
    503 => "Service Unavailable",
    504 => "Gateway Timeout"
  }.freeze

end

#   def initialize
  
#   end

#   def map_request_to_grpc_request(request, operation_id, requester_user_id)
#     case operation_id
#     when "registerUser"
#       UserAPIGatewayService::RegisterUserRequest.new(
#         email:          request[:body]["email"],
#         password:       request[:body]["password"],
#         display_name:   request[:body]["display_name"],
#         avatar:         request[:body]["avatar"] )
#     when "getUserProfile"
#       UserAPIGatewayService::GetUserProfileRequest.new(
#         requester_user_id: requester_user_id,
#         user_id:           request[:path_params]["user_id"] )
#     when "getUserStatus"
#       UserAPIGatewayService::GetUserStatusRequest.new(
#         requester_user_id:  requester_user_id,
#         user_id:            request[:path_params]["user_id"] )
#     when "getUserMatches"
#       MatchAPIGatewayService::GetUserMatchesRequest.new(
#         requester_user_id:  requester_user_id,
#         user_id:            request[:path_params]["user_id"],
#         limit:              request[:query_params]["limit"],
#         offset:             request[:query_params]["offset"] )
#     when "getUserTournaments"
#       TournamentAPIGatewayService::GetUserTournamentsRequest.new(
#         requester_user_id:  requester_user_id,
#         user_id:            request[:path_params]["user_id"],
#         limit:              request[:query_params]["limit"],
#         offset:             request[:query_params]["offset"] )
#     when "deleteAccount"
#       UserAPIGatewayService::DeleteAccountRequest.new(
#         requester_user_id: requester_user_id, )
#     when "getPrivateProfile"
#       UserAPIGatewayService::GetPrivateProfileRequest.new(
#         requester_user_id: requester_user_id )
#     when "updateProfile"
#       UserAPIGatewayService::UpdateProfileRequest.new(
#         requester_user_id:  requester_user_id,
#         display_name:       request[:body]["display_name"],
#         avatar:             request[:body]["avatar"] )
#     # when "updatePassword"
#     #   UserAPIGatewayService::UpdatePasswordRequest.new(
#     #     requester_user_id: requester_user_id,
#     #     old_password: request[:body]["old_password"],
#     #     new_password: request[:body]["new_password"] )
#     # when "requestPasswordReset"
#     #   UserAPIGatewayService::RequestPasswordResetRequest.new(
#     #     email: request[:body]["email"] )
#     # when "checkPasswordResetToken"
#     #   UserAPIGatewayService::CheckPasswordResetTokenRequest.new(
#     #     token: request[:path_params]["token"] )
#     # when "resetPassword"
#     #   UserAPIGatewayService::ResetPasswordRequest.new(
#     #     token: request[:path_params]["token"],
#     #     new_password: request[:body]["new_password"], )
#     # when "updateEmail"
#     #   UserAPIGatewayService::UpdateEmailRequest.new(
#     #     requester_user_id: requester_user_id,
#     #     new_email: request[:body]["new_email"],
#     #     current_password: request[:body]["current_password"],
#     #     totp_code: request[:body]["totp_code"] )
#     # when "verifyEmail"
#     #   UserAPIGatewayService::VerifyEmailRequest.new(
#     #     requester_user_id: requester_user_id )
#     # when "checkEmailVerificationToken"
#     #   UserAPIGatewayService::CheckEmailVerificationTokenRequest.new(
#     #     token: request[:path_params]["token"] )
#     when "enable2FA"
#       UserAPIGatewayService::Enable2FARequest.new(
#         requester_user_id: requester_user_id )
#     when "get2FAStatus"
#       UserAPIGatewayService::Get2FAStatusRequest.new(
#         requester_user_id: requester_user_id )
#     when "disable2FA"
#       UserAPIGatewayService::Disable2FARequest.new(
#         requester_user_id: requester_user_id )
#     when "check2FACode"
#       UserAPIGatewayService::Check2FACodeRequest.new(
#         requester_user_id: requester_user_id,
#         totp_code:         request[:body]["totp_code"] )
#     when "loginUser"
#       UserAPIGatewayService::LoginUserRequest.new(
#         email:      request[:body]["email"],
#         password:   request[:body]["password"] )
#     when "addFriend"
#       UserAPIGatewayService::AddFriendRequest.new(
#         requester_user_id: requester_user_id,
#         friend_id:         request[:body]["friend_id"] )
#     when "getFriends"
#       UserAPIGatewayService::GetFriendsRequest.new(
#         requester_user_id: requester_user_id,
#         limit:  request[:query_params]["limit"],
#         offset: request[:query_params]["offset"] )
#     when "removeFriend"
#       UserAPIGatewayService::RemoveFriendRequest.new(
#         requester_user_id: requester_user_id,
#         friend_id:         request[:path_params]["friend_id"] )
#     when "createMatch"
#       MatchAPIGatewayService::CreateMatchRequest.new(
#         requester_user_id:  requester_user_id,
#         invited_user_ids:   request[:body]["invited_user_ids"] )
#     when "joinMatch"
#       MatchAPIGatewayService::JoinMatchRequest.new(
#         requester_user_id: requester_user_id,
#         match_id:          request[:path_params]["match_id"] )
#     when "getMatch"
#       MatchAPIGatewayService::GetMatchRequest.new(
#         requester_user_id: requester_user_id,
#         match_id:          request[:path_params]["match_id"] )
#     when "leaveMatch"
#       MatchAPIGatewayService::LeaveMatchRequest.new(
#         requester_user_id: requester_user_id,
#         match_id:          request[:path_params]["match_id"] )
#     when "createTournament"
#       TournamentAPIGatewayService::CreateTournamentRequest.new(
#         requester_user_id:  requester_user_id,
#         invited_user_ids:   request[:body]["invited_user_ids"] )
#     when "joinTournament"
#       TournamentAPIGatewayService::JoinTournamentRequest.new(
#         requester_user_id: requester_user_id,
#         tournament_id:     request[:path_params]["tournament_id"] )
#     when "getTournament"
#       TournamentAPIGatewayService::GetTournamentRequest.new(
#         requester_user_id:  requester_user_id,
#         tournament_id:      request[:path_params]["tournament_id"] )
#     when "leaveTournament"
#       TournamentAPIGatewayService::LeaveTournamentRequest.new(
#         requester_user_id:  requester_user_id,
#         tournament_id:      request[:path_params]["tournament_id"] )
#     else
#       raise ActionFailedException::NotImplemented
#     end
#   end

#   def map_grpc_response_to_response(grpc_response, operation_id)
#     case operation_id
#     when "registerUser"
#       status_code = grpc_response.status_code || 500
#       return Response.new(status_code, {}, nil) if status_code >= 400

#       user_id = grpc_response.user_id
#       body = { user_id: user_id }
#       headers = {
#         "Content-Length" => body.to_json.bytesize.to_s,
#       }.compact
    
#       Response.new(status_code, headers, body)    
#     when "getUserProfile"
#       status_code = grpc_response.status_code || 500
#       return Response.new(status_code, {}, nil) if status_code >= 400

#       user = grpc_response.user
#       body = {
#         user_id:      user.user_id,
#         display_name: user.display_name,
#         avatar:       user.avatar,
#         status:       user.status,
#       }.compact
#       headers = {
#         "Content-Length" => body.to_json.bytesize.to_s,
#       }.compact
    
#       Response.new(status_code, headers, body)    
#     when "getUserStatus"
#       status_code = grpc_response.status_code || 500
#       return Response.new(status_code, {}, nil) if status_code >= 400

#       status = grpc_response.status
#       body = { status: status }
#       headers = {
#         "Content-Length" => body.to_json.bytesize.to_s,
#       }.compact
    
#       Response.new(status_code, headers, body)    
#     when "getUserMatches"
#       status_code = grpc_response.status_code || 500
#       return Response.new(status_code, {}, nil) if status_code >= 400

#       matches = grpc_response.matches || []
#       body = matches.map do |match|
#         {
#           id: match.id,
#           player_ids:         match.player_ids,
#           status:             match.status,
#           started_timestamp:  match.started_timestamp,
#           finished_timestamp: match.finished_timestamp,
#         }.compact
#       end.presence || nil
#       headers = {
#         "Content-Length" => body.to_json.bytesize.to_s,
#       }.compact
    
#       Response.new(status_code, headers, body)    
#     when "getUserTournaments"
#       status_code = grpc_response.status_code || 500
#       return Response.new(status_code, {}, nil) if status_code >= 400

#       tournaments = grpc_response.tournaments || []
#       body = tournaments.map do |tournament|
#         {
#           id: tournament.id,
#           match_ids:          tournament.match_ids,
#           status:             tournament.status,
#           started_timestamp:  tournament.started_timestamp,
#           finished_timestamp: tournament.finished_timestamp,
#         }.compact
#       end.presence || nil
#       headers = {
#         "Content-Length" => body.to_json.bytesize.to_s,
#       }.compact
    
#       Response.new(status_code, headers, body)
#     when "deleteAccount"
#       status_code = grpc_response.status_code || 500
#       Response.new(status_code, {}, nil)
#     when "getPrivateProfile"
#       status_code = grpc_response.status_code || 500
#       return Response.new(status_code, {}, nil) if status_code >= 400

#       user = grpc_response.user
#       body = {
#         id: user.id,
#         display_name:             user.display_name,
#         avatar:                   user.avatar,
#         status:                   user.status,
#         email:                    user.email,
#         two_factor_auth_enabled:  user.two_factor_auth_enabled
#       }.compact
#       headers = {
#         "Content-Length" => body.to_json.bytesize.to_s,
#       }.compact

#       Response.new(status_code, headers, body)
#     when "updateProfile"
#       status_code = grpc_response.status_code || 500
#       Response.new(status_code, {}, nil)
#     # when "updatePassword"
#     #   status_code = grpc_response.status_code || 500
#     #   Response.new(status_code, {}, nil)
#     # when "requestPasswordReset"
#     #   status_code = grpc_response.status_code || 500
#     #   Response.new(status_code, {}, nil)
#     # when "checkPasswordResetToken"
#     #   status_code = grpc_response.status_code || 500
#     #   Response.new(status_code, {}, nil)
#     # when "resetPassword"
#     #   status_code = grpc_response.status_code || 500
#     #   Response.new(status_code, {}, nil)
#     # when "updateEmail"
#     #   status_code = grpc_response.status_code || 500
#     #   Response.new(status_code, {}, nil)
#     # when "verifyEmail"
#     #   status_code = grpc_response.status_code || 500
#     #   Response.new(status_code, {}, nil)
#     # when "checkEmailVerificationToken"
#     #   status_code = grpc_response.status_code || 500
#     #   Response.new(status_code, {}, nil)
#     when "enable2FA"
#       status_code = grpc_response.status_code || 500
#       return Response.new(status_code, {}, nil) if status_code >= 400

#       totp_secret = grpc_response.totp_secret
#       body = { totp_secret: totp_secret }
#       headers = {
#         "Content-Length" => body.to_json.bytesize.to_s,
#       }.compact

#       Response.new(status_code, headers, body)
#     when "get2FAStatus"
#       status_code = grpc_response.status_code || 500
#       return Response.new(status_code, {}, nil) if status_code >= 400

#       two_factor_auth_enabled = grpc_response.two_factor_auth_enabled
#       body = { two_factor_auth_enabled: two_factor_auth_enabled } if two_factor_auth_enabled
#       headers = {
#         "Content-Length" => body.to_json.bytesize.to_s,
#       }.compact

#       Response.new(status_code, headers, body)
#     when "disable2FA"
#       status_code = grpc_response.status_code || 500
#       Response.new(status_code, {}, nil)
#     when "check2FACode"
#       status_code = grpc_response.status_code || 500
#       Response.new(status_code, {}, nil)
#     when "loginUser"
#       status_code = grpc_response.status_code || 500
#       return Response.new(status_code, {}, nil) if status_code >= 400

#       jwt = grpc_response.jwt
#       body = { jwt: jwt }
#       headers = {
#         "Content-Length" => body.to_json.bytesize.to_s,
#       }.compact

#       Response.new(status_code, headers, body)
#     when "addFriend"
#       status_code = grpc_response.status_code || 500
#       Response.new(status_code, {}, nil)
#     when "getFriends"
#       status_code = grpc_response.status_code || 500
#       return Response.new(status_code, {}, nil) if status_code >= 400

#       friend_ids = grpc_response.friend_ids
#       body = { friend_ids: friend_ids }
#       headers = {
#         "Content-Length" => body.to_json.bytesize.to_s,
#       }.compact

#       Response.new(status_code, headers, body)
#     when "removeFriend"
#       status_code = grpc_response.status_code || 500
#       Response.new(status_code, {}, nil)
#     else
#       raise ActionFailedException::NotImplemented
#     end
#   end
    
# end
