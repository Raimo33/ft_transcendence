# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Mapper.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:43:53 by craimond          #+#    #+#              #
#    Updated: 2024/10/31 22:39:50 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'proto/user_pb'
require_relative 'proto/match_pb'
require_relative 'proto/tournament_pb'
require_relative 'structs'

module Mapper

  PLAYER_MATCH_SORTING_OPTIONS_MAP = {
    'age' => YourPackage::PlayerMatchSortingOptions::AGE,
    'duration' => YourPackage::PlayerMatchSortingOptions::DURATION,
    'number_of_players' => YourPackage::PlayerMatchSortingOptions::NUMBER_OF_PLAYERS,
    'position' => YourPackage::PlayerMatchSortingOptions::POSITION
  }.freeze

  PLAYER_TOURNAMENT_SORTING_OPTIONS_MAP = {
    'age' => YourPackage::PlayerTournamentSortingOptions::AGE,
    'duration' => YourPackage::PlayerTournamentSortingOptions::DURATION,
    'number_of_players' => YourPackage::PlayerTournamentSortingOptions::NUMBER_OF_PLAYERS,
    'position' => YourPackage::PlayerTournamentSortingOptions::POSITION
  }.freeze

  USER_PROFILE_SORTING_OPTIONS_MAP = {
    'display_name' => YourPackage::UserProfileSortingOptions::DISPLAY_NAME,
    'registered_timestamp' => YourPackage::UserProfileSortingOptions::REGISTERED_TIMESTAMP,
    'last_active_timestamp' => YourPackage::UserProfileSortingOptions::LAST_ACTIVE_TIMESTAMP
  }.freeze


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
      UserService::GetUserRequest.new(
        requesting_user_id: requesting_user_id,
        user_id: request[:path_params]["user_id"] )
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
        sort_by: PLAYER_MATCH_SORTING_OPTIONS_MAP[request[:query_params]["sort_by"]],
        filters: request[:query_params]["filters"] ?
          MatchService::PlayerMatchFilters.new(
            status: request[:query_params]["filters"]["status"],
            position: request[:query_params]["filters"]["position"], )
        : nil )
    when "getUserTournaments"
      TournamentService::GetUserTournamentsRequest.new(
        requesting_user_id: requesting_user_id,
        user_id: request[:path_params]["user_id"],
        limit: request[:query_params]["limit"],
        offset: request[:query_params]["offset"],
        sort_by: PLAYER_TOURNAMENT_SORTING_OPTIONS_MAP[request[:query_params]["sort_by"]],
        filters: request[:query_params]["filters"] ?
          TournamentService::PlayerTournamentFilters.new(
            mode: request[:query_params]["filters"]["mode"],
            status: request[:query_params]["filters"]["status"],
            position: request[:query_params]["filters"]["position"], )
        : nil )
    when "deleteAccount"
      UserService::DeleteAccountRequest.new(
        requesting_user_id: requesting_user_id, )
    when "getPrivateProfile"
      UserService::GetPrivateProfileRequest.new(
        requesting_user_id: requesting_user_id )
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
        sort_by: USER_PROFILE_SORTING_OPTIONS_MAP[request[:query_params]["sort_by"]],
        filters: request[:query_params]["filters"] ?
          UserService::UserProfileFilters.new(
            status: request[:query_params]["filters"]["status"] )
        : nil )
    when "removeFriend"
      UserService::RemoveFriendRequest.new(
        requesting_user_id: requesting_user_id,
        friend_id: request[:path_params]["friend_id"] )
    else
      raise #TODO internal
    end
  end

  def self.map_grpc_response_to_response(grpc_response, operation_id)
    case operation_id
    when "registerUser"
      Response.new(
        status_code: grpc_response.status_code,
        headers: #TODO aggiungere headers (capire se automatizzabile)
        body: grpc_response.user_id ? { user_id: grpc_response.user_id } : nil )
    when "getUserProfile"
      Response.new(
        status_code: grpc_response.status_code,
        headers: #TODO aggiungere headers (capire se automatizzabile)
        body: grpc_response.user ? {
          user_id: grpc_response.user.user_id,
          display_name: grpc_response.user.display_name,
          avatar: grpc_response.user.avatar,
          status: grpc_response.user.status,
          last_active_timestamp: grpc_response.user.last_active_timestamp,
          registered_timestamp: grpc_response.user.registered_timestamp,
        } : nil )
    #TODO add more response mappings
    else
      raise #TODO internal
    end
  end
    
end
