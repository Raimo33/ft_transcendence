# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcClient.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/16 16:41:55 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require_relative "ConfigLoader"
require_relative "ConfigurableLogger"
require_relative "../proto/user_api_gateway_pb"
require_relative "../proto/match_api_gateway_pb"
require_relative "../proto/tournament_api_gateway_pb"

class GrpcClient

  def initialize
    @config = ConfigLoader.instance.config
    @logger = ConfigurableLogger.instance.logger
    @logger.info("Initializing grpc client")

    options = {
      "grpc.compression_algorithm" => "gzip"
    }

    user_channel        = create_channel(@config[:addresses][:user], :this_channel_is_insecure)
    match_channel       = create_channel(@config[:addresses][:match], :this_channel_is_insecure)
    tournament_channel  = create_channel(@config[:addresses][:tournament], :this_channel_is_insecure)
    auth_channel        = create_channel(@config[:addresses][:auth], :this_channel_is_insecure)

    @stubs = {
      user: User::Stub.new(user_channel),
      match: Match::Stub.new(match_channel),
      tournament: Tournament::Stub.new(tournament_channel),
      auth: Auth::Stub.new(auth_channel)
    }.freeze

    @request_mapping = {
      UserAPIGatewayService::RegisterUserRequest                  => { stub: @stubs[:user],       method: :register_user },
      UserAPIGatewayService::GetUserProfileRequest                => { stub: @stubs[:user],       method: :get_user_profile },
      UserAPIGatewayService::GetUserStatusRequest                 => { stub: @stubs[:user],       method: :get_user_status },
      MatchAPIGatewayService::GetUserMatchesRequest               => { stub: @stubs[:match],      method: :get_user_matches },
      TournamentAPIGatewayService::GetUserTournamentsRequest      => { stub: @stubs[:tournament], method: :get_user_tournaments },
      UserAPIGatewayService::DeleteAccountRequest                 => { stub: @stubs[:user],       method: :delete_account },
      UserAPIGatewayService::GetPrivateProfileRequest             => { stub: @stubs[:user],       method: :get_private_profile },
      UserAPIGatewayService::UpdateProfileRequest                 => { stub: @stubs[:user],       method: :update_profile },
      # UserAPIGatewayService::UpdatePasswordRequest                => { stub: @stubs[:user],       method: :update_password },
      # UserAPIGatewayService::RequestPasswordResetRequest          => { stub: @stubs[:user],       method: :request_password_reset },
      # UserAPIGatewayService::CheckPasswordResetTokenRequest       => { stub: @stubs[:user],       method: :check_password_reset_token },
      # UserAPIGatewayService::ResetPasswordRequest                 => { stub: @stubs[:user],       method: :reset_password },
      # UserAPIGatewayService::UpdateEmailRequest                   => { stub: @stubs[:user],       method: :update_email },
      # UserAPIGatewayService::VerifyEmailRequest                   => { stub: @stubs[:user],       method: :verify_email },
      # UserAPIGatewayService::CheckEmailVerificationTokenRequest   => { stub: @stubs[:user],       method: :check_email_verification_token },
      UserAPIGatewayService::Enable2FARequest                     => { stub: @stubs[:user],       method: :enable_2fa },
      UserAPIGatewayService::Get2FAStatusRequest                  => { stub: @stubs[:user],       method: :get_2fa_status },
      UserAPIGatewayService::Disable2FARequest                    => { stub: @stubs[:user],       method: :disable_2fa },
      UserAPIGatewayService::Check2FACodeRequest                  => { stub: @stubs[:user],       method: :check_2fa_code },
      UserAPIGatewayService::LoginUserRequest                     => { stub: @stubs[:user],       method: :login_user },
      UserAPIGatewayService::AddFriendRequest                     => { stub: @stubs[:user],       method: :add_friend },
      UserAPIGatewayService::GetFriendsRequest                    => { stub: @stubs[:user],       method: :get_friends },
      UserAPIGatewayService::RemoveFriendRequest                  => { stub: @stubs[:user],       method: :remove_friend },
      MatchAPIGatewayService::CreateMatchRequest                  => { stub: @stubs[:match],      method: :create_match },
      MatchAPIGatewayService::JoinMatchRequest                    => { stub: @stubs[:match],      method: :join_match },
      MatchAPIGatewayService::GetMatchRequest                     => { stub: @stubs[:match],      method: :get_match },
      MatchAPIGatewayService::LeaveMatchRequest                   => { stub: @stubs[:match],      method: :leave_match },
      TournamentAPIGatewayService::CreateTournamentRequest        => { stub: @stubs[:tournament], method: :create_tournament },
      TournamentAPIGatewayService::JoinTournamentRequest          => { stub: @stubs[:tournament], method: :join_tournament },
      TournamentAPIGatewayService::GetTournamentRequest           => { stub: @stubs[:tournament], method: :get_tournament },
      TournamentAPIGatewayService::LeaveTournamentRequest         => { stub: @stubs[:tournament], method: :leave_tournament },
    }.freeze

  rescue StandardError => e
    raise "Failed to initialize grpc client: #{e}"
  ensure
    close
  end

  def call(grpc_request)
    mapping = @request_mapping[grpc_request.class]
    raise "No mapping found for request: #{grpc_request.class}" unless mapping

    stub = mapping[:stub]
    method = mapping[:method]
    @logger.debug("Calling grpc method #{method} with request: #{grpc_request} on stub: #{stub}")
    response = stub.send(method, grpc_request)
    @logger.debug("Received response: #{response}")

  rescue StandardError => e
    raise "Failed to call grpc method #{method}: #{e}"
  end

  def close
    @logger.info("Closing grpc client")
    @stubs.each do |channel|
      channel&.close if defined?(channel) && channel.respond_to?(:close)
    end
  end

  private

  def create_channel(addr, credentials)
    @logger.debug("Creating channel to #{addr}")
    GRPC::Core::Channel.new(addr, nil, credentials)
  rescue StandardError => e
    raise "Failed to create channel to #{addr}: #{e}"
  end

end
