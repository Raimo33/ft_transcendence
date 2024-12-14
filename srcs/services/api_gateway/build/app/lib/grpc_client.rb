# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    grpc_client.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:37:07 by craimond          #+#    #+#              #
#    Updated: 2024/12/14 14:02:48 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'yaml'
require 'singleton'
require_relative 'ConfigHandler'
require_relative '../protos/user_api_gateway_services_pb'
require_relative '../protos/match_api_gateway_services_pb'
require_relative '../protos/tournament_api_gateway_services_pb'
require_relative 'middleware/client/logger_interceptor'

class GrpcClient
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config

    @connection_options = {
      "grpc.compression_algorithm" => "gzip"
    }

    interceptors = [LoggerInterceptor.new]

    channels = {
      user:         create_channel(@config.dig(:grpc, :client, :addresses, :user)),
      match:        create_channel(@config.dig(:grpc, :client, :addresses, :match)),
      tournament:   create_channel(@config.dig(:grpc, :client, :addresses, :tournament))
      auth:         create_channel(@config.dig(:grpc, :client, :addresses, :auth))
    }

    @stubs = {
      user:       UserAPIGateway::Stub.new(channels[:user], interceptors: interceptors),
      match:      MatchAPIGateway::Stub.new(channels[:match], interceptors: interceptors),
      tournament: TournamentAPIGateway::Stub.new(channels[:tournament], interceptors: interceptors)
      auth:       AuthAPIGateway::Stub.new(channels[:auth], interceptors: interceptors)
    }

  end

  def stop
    @channels.each_value(&:close)
  end

  def register_user(email:, password:, display_name:, metadata = {})
    request = UserAPIGateway::RegisterUserRequest.new(email: email, password: password, display_name: display_name)
    @stubs[:user].register_user(request, metadata: metadata)
  end

  def get_user_public_profile(user_id:, metadata = {})
    request = UserAPIGateway::Identifier.new(id: user_id)
    @stubs[:user].get_user_public_profile(request, metadata: metadata)
  end

  def get_user_status(user_id:, metadata = {})
    request = UserAPIGateway::Identifier.new(id: user_id)
    @stubs[:user].get_user_status(request, metadata: metadata)
  end

  def get_user_matches(user_id:, cursor:, limit:, metadata = {})
    request = UserAPIGateway::GetUserMatchesRequest.new(user_id: user_id, cursor: cursor, limit: limit)
    @stubs[:match].get_user_matches(request, metadata: metadata)
  end

  def get_user_tournaments(user_id:, cursor:, limit:, metadata = {})
    request = UserAPIGateway::GetUserMatchesRequest.new(user_id: user_id, cursor: cursor, limit: limit)
    @stubs[:tournament].get_user_tournaments(request, metadata: metadata)
  end

  def delete_account(metadata = {})
    @stubs[:user].delete_account(Empty.new, metadata: metadata)
  end

  def get_user_private_profile(metadata = {})
    @stubs[:user].get_user_private_profile(Empty.new, metadata: metadata)
  end

  def update_profile(display_name:, avatar:, metadata = {})
    request = UserAPIGateway::UpdateProfileRequest.new(display_name: display_name, avatar: avatar)
    @stubs[:user].update_profile(request, metadata: metadata)
  end

  def enable_tfa(metadata = {})
    @stubs[:user].enable_tfa(Empty.new, metadata: metadata)
  end

  def disable_tfa(code:, metadata = {})
    request = UserAPIGateway::TFACode.new(code: tfa_code)
    @stubs[:user].disable_tfa(request, metadata: metadata)
  end

  def submit_tfa_code(code:, metadata = {})
    request = UserAPIGateway::TFACode.new(code: code)
    @stubs[:user].submit_tfa_code(request, metadata: metadata)
  end

  def login_user(email:, password:, metadata = {})
    request = UserAPIGateway::LoginUserRequest.new(email: email, password: password)
    @stubs[:user].login_user(request, metadata: metadata)
  end

  def refresh_user_session_token(metadata = {})
    @stubs[:user].refresh_user_session_token(Empty.new, metadata: metadata)
  end
  
  def logout_user(metadata = {})
    @stubs[:user].logout_user(Empty.new, metadata: metadata)
  end

  def add_friend(friend_id:, metadata = {})
    request = UserAPIGateway::Identifier.new(id: friend_id)
    @stubs[:user].add_friend(request, metadata: metadata)
  end

  def get_friends(cursor:, limit:, metadata = {})
    request = UserAPIGateway::GetFriendsRequest.new(cursor: cursor, limit: limit)
    @stubs[:user].get_friends(request, metadata: metadata)
  end

  def remove_friend(friend_id:, metadata = {})
    request = UserAPIGateway::Identifier.new(id: friend_id)
    @stubs[:user].remove_friend(request, metadata: metadata)
  end

  def create_match(opponent_id:, metadata = {})
    request = MatchAPIGateway::Identifier.new(id: opponent_id)
    @stubs[:match].create_match(request, metadata: metadata)
  end

  def get_match(match_id:, metadata = {})
    request = MatchAPIGateway::Identifier.new(id: match_id)
    @stubs[:match].get_match(request, metadata: metadata)
  end

  def leave_match(match_id:, metadata = {})
    request = MatchAPIGateway::Identifier.new(id: match_id)
    @stubs[:match].leave_match(request, metadata: metadata)
  end

  def accept_match_invitation(match_id:, metadata = {})
    request = MatchAPIGateway::Identifier.new(id: match_id)
    @stubs[:match].accept_match_invitation(request, metadata: metadata)
  end

  def decline_match_invitation(match_id:, metadata = {})
    request = MatchAPIGateway::Identifier.new(id: match_id)
    @stubs[:match].decline_match_invitation(request, metadata: metadata)
  end

  def create_tournament(metadata = {})
    @stubs[:tournament].create_tournament(Empty.new, metadata: metadata)
  end

  def get_tournament(tournament_id:, metadata = {})
    request = TournamentAPIGateway::Identifier.new(id: tournament_id)
    @stubs[:tournament].get_tournament(request, metadata: metadata)
  end

  def cancel_tournament(tournament_id:, metadata = {})
    request = TournamentAPIGateway::Identifier.new(id: tournament_id)
    @stubs[:tournament].cancel_tournament(request, metadata: metadata)
  end

  def join_tournament(tournament_id:, metadata = {})
    request = TournamentAPIGateway::Identifier.new(id: tournament_id)
    @stubs[:tournament].join_tournament(request, metadata: metadata)
  end

  def leave_tournament(tournament_id:, metadata = {})
    request = TournamentAPIGateway::Identifier.new(id: tournament_id)
    @stubs[:tournament].leave_tournament(request, metadata: metadata)
  end

  def validate_session_token(jwt:, required_auth_level:, metadata = {})
    request = AuthAPIGateway::ValidateSessionTokenRequest.new(jwt: jwt, required_auth_level: required_auth_level) #TODO capire se usare COMMON invece che AuthAPIGateway
    @stubs[:auth].validate_session_token(request, metadata: metadata)
  end

  private

  def create_channel(addr)
    GRPC::Core::Channel.new(addr, @connection_options, credentials: :this_channel_is_insecure)
  end
  
end

