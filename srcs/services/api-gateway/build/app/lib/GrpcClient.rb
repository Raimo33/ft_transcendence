# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcClient.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/12 12:27:20 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require_relative "ConfigLoader"
require_relative "ConfigurableLogger"
require_relative "../proto/user_service_pb"
require_relative "../proto/match_service_pb"
require_relative "../proto/tournament_service_pb"

class GrpcClient

  def initialize
    @config = ConfigLoader.instance.config
    @logger = ConfigurableLogger.instance.logger
    @logger.info("Initializing grpc client")

    options = {
      "grpc.compression_algorithm" => "gzip"
    }

    user_credentials        = load_credentials(@config[:credentials][:certs][:user])
    match_credentials       = load_credentials(@config[:credentials][:certs][:match])
    tournament_credentials  = load_credentials(@config[:credentials][:certs][:tournament])
    auth_credentials        = load_credentials(@config[:credentials][:certs][:auth])

    user_channel        = create_channel(@config[:addresses][:user], user_credentials)
    match_channel       = create_channel(@config[:addresses][:match], match_credentials)
    tournament_channel  = create_channel(@config[:addresses][:tournament], tournament_credentials)
    auth_channel        = create_channel(@config[:addresses][:auth], auth_credentials)

    @stubs = {
      user: User::Stub.new(user_channel),
      match: Match::Stub.new(match_channel),
      tournament: Tournament::Stub.new(tournament_channel),
      auth: Auth::Stub.new(auth_channel)
    }.freeze

    @request_mapping = {
      UserService::RegisterUserRequest                  => { stub: @stubs[:user],       method: :register_user },
      UserService::GetUserProfileRequest                => { stub: @stubs[:user],       method: :get_user_profile },
      UserService::GetUserStatusRequest                 => { stub: @stubs[:user],       method: :get_user_status },
      MatchService::GetUserMatchesRequest               => { stub: @stubs[:match],      method: :get_user_matches },
      TournamentService::GetUserTournamentsRequest      => { stub: @stubs[:tournament], method: :get_user_tournaments },
      UserService::DeleteAccountRequest                 => { stub: @stubs[:user],       method: :delete_account },
      UserService::GetPrivateProfileRequest             => { stub: @stubs[:user],       method: :get_private_profile },
      UserService::UpdateProfileRequest                 => { stub: @stubs[:user],       method: :update_profile },
      UserService::UpdatePasswordRequest                => { stub: @stubs[:user],       method: :update_password },
      UserService::RequestPasswordResetRequest          => { stub: @stubs[:user],       method: :request_password_reset },
      UserService::CheckPasswordResetTokenRequest       => { stub: @stubs[:user],       method: :check_password_reset_token },
      UserService::ResetPasswordRequest                 => { stub: @stubs[:user],       method: :reset_password },
      UserService::UpdateEmailRequest                   => { stub: @stubs[:user],       method: :update_email },
      UserService::VerifyEmailRequest                   => { stub: @stubs[:user],       method: :verify_email },
      UserService::CheckEmailVerificationTokenRequest   => { stub: @stubs[:user],       method: :check_email_verification_token },
      UserService::Enable2FARequest                     => { stub: @stubs[:user],       method: :enable_2fa },
      UserService::Get2FAStatusRequest                  => { stub: @stubs[:user],       method: :get_2fa_status },
      UserService::Disable2FARequest                    => { stub: @stubs[:user],       method: :disable_2fa },
      UserService::Check2FACodeRequest                  => { stub: @stubs[:user],       method: :check_2fa_code },
      UserService::LoginUserRequest                     => { stub: @stubs[:user],       method: :login_user },
      UserService::LogoutUserRequest                    => { stub: @stubs[:user],       method: :logout_user },
      UserService::AddFriendRequest                     => { stub: @stubs[:user],       method: :add_friend },
      UserService::GetFriendsRequest                    => { stub: @stubs[:user],       method: :get_friends },
      UserService::RemoveFriendRequest                  => { stub: @stubs[:user],       method: :remove_friend },
      MatchService::CreateMatchRequest                  => { stub: @stubs[:match],      method: :create_match },
      MatchService::JoinMatchRequest                    => { stub: @stubs[:match],      method: :join_match },
      MatchService::GetMatchRequest                     => { stub: @stubs[:match],      method: :get_match },
      MatchService::LeaveMatchRequest                   => { stub: @stubs[:match],      method: :leave_match },
      TournamentService::CreateTournamentRequest        => { stub: @stubs[:tournament], method: :create_tournament },
      TournamentService::JoinTournamentRequest          => { stub: @stubs[:tournament], method: :join_tournament },
      TournamentService::GetTournamentRequest           => { stub: @stubs[:tournament], method: :get_tournament },
      TournamentService::LeaveTournamentRequest         => { stub: @stubs[:tournament], method: :leave_tournament },
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

  def load_credentials(cert_file)
    raise "Certificate file not found: #{cert_file}" unless File.exist?(cert_file)
    @logger.debug("Loading credentials from #{cert_file}")
    GRPC::Core::ChannelCredentials.new(File.read(cert_file))
  rescue StandardError => e
    raise "Failed to load credentials from #{cert_file}: #{e}"
  end

  def create_channel(addr, credentials)
    @logger.debug("Creating channel to #{addr}")
    GRPC::Core::Channel.new(addr, nil, credentials)
  rescue StandardError => e
    raise "Failed to create channel to #{addr}: #{e}"
  end

end
