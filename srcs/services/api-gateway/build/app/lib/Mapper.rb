# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Mapper.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:43:53 by craimond          #+#    #+#              #
#    Updated: 2024/10/29 20:42:39 by craimond         ###   ########.fr        #
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

  def self.map_request_to_grpc_request(request, operation_id)
    case operation_id
    when "ping"
      #TODO non inoltrare, gestire internamente
    when "registerUser"
      UserService::RegisterUserRequest.new(
        email: request[:body]["email"],
        password: request[:body]["password"],
        display_name: request[:body]["display_name"],
        avatar: request[:body]["avatar"] )
    when "getUser"
      UserService::GetUserRequest.new(
        user_id: request[:path_params]["user_id"] )
    when "deleteUser"
      UserService::DeleteUserRequest.new(
        user_id: request[:path_params]["user_id"] )
    when "getUserProfile"
      UserService::GetUserProfileRequest.new(
        user_id: request[:path_params]["user_id"] )
    when "updateUserProfile"
      UserService::UpdateUserProfileRequest.new(
        user_id: request[:path_params]["user_id"],
        display_name: request[:body]["display_name"],
        avatar: request[:body]["avatar"] )
    when "updateUserPassword"
      UserService::UpdateUserPasswordRequest.new(
        user_id: request[:path_params]["user_id"],
        old_password: request[:body]["old_password"],
        new_password: request[:body]["new_password"] )
    when "updateUserEmail"
      UserService::UpdateUserEmailRequest.new(
        user_id: request[:path_params]["user_id"],
        new_email: request[:body]["new_email"] )
    when "verifyUserEmail"
      UserService::VerifyUserEmailRequest.new(
        user_id: request[:path_params]["user_id"], )
    when "verifyEmailVerificationToken"
      UserService::VerifyEmailVerificationTokenRequest.new(
        user_id: request[:path_params]["user_id"],
        token: request[:path_params]["token"] )
    when "enable2FA"
      UserService::Enable2FARequest.new(
        user_id: request[:path_params]["user_id"], )
    when "get2FAStatus"
      UserService::Get2FAStatusRequest.new(
        user_id: request[:path_params]["user_id"], )
    when "disable2FA"
      UserService::Disable2FARequest.new(
        user_id: request[:path_params]["user_id"], )
    when "verify2FACode"
      UserService::Verify2FACodeRequest.new(
        user_id: request[:path_params]["user_id"],
        code: request[:body]["totp_code"] )
    when "getUserMatches"
      MatchService::GetUserMatchesRequest.new(
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
    #TODO Add more request mappings
    else
      raise #TODO internal
    end
  end

  def self.map_grpc_response_to_response(grpc_response, operation_id)
    case operation_id
    when "ping"
      #TODO
    when "registerUser"
      Response.new(
        status_code: grpc_response.status_code,
        headers: #TODO aggiungere headers (capire se automatizzabile)
        body: grpc_response.user_id )
    when "getUser"
      Response.new(
        status_code: grpc_response.status_code,
        headers: #TODO aggiungere headers (capire se automatizzabile)
        body: grpc_response.user ? {
          user_id: grpc_response.user.user_id,
          display_name: grpc_response.user.display_name,
          avatar: grpc_response.user.avatar,
          status: grpc_response.user.status,
          last_active: grpc_response.user.last_active,
          registered_timestamp: grpc_response.user.registered_timestamp,
          email: grpc_response.user.email,
          two_factor_auth: grpc_response.user.two_factor_auth,
        } : nil )
    #TODO add more response mappings
    else
      raise #TODO internal
    end
  end

  def self.map_sorting_options(sorting)
    #TODO returns an array of sorting options enums
    
end
