# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Mapper.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:43:53 by craimond          #+#    #+#              #
#    Updated: 2024/10/29 17:00:43 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'proto/user_pb'
require_relative 'proto/match_pb'
require_relative 'proto/tournament_pb'
require_relative 'structs'

module Mapper

  def self.map_request_to_grpc_request(request, operation_id)
    case operation_id
    when "ping"
      #TODO
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
        } : nil
      )
    #TODO add more response mappings
    else
      raise #TODO internal
    end
  end
end
