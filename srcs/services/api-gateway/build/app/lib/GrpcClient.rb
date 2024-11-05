# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcClient.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/05 17:39:08 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../proto/users_services_pb'
require_relative '../proto/match_services_pb'
require_relative '../proto/tournament_services_pb'
require_relative './modules/ConfigLoader'
require_relative './modules/Logger'

class GrpcClient
  include ConfigLoader
  include Logger

  def initialize
    @config = ConfigLoader.config
    @logger = Logger.logger
    @logger.info('Initializing grpc client')

    options = {
      'grpc.compression_algorithm' => 'gzip'
    }

    user_server_credentials        = load_credentials(@config[:user_server_cert])
    match_server_credentials       = load_credentials(@config[:match_server_cert])
    tournament_server_credentials  = load_credentials(@config[:tournament_server_cert])

    user_channel        = create_channel(@config[:user_server_addr], user_server_credentials)
    match_channel       = create_channel(@config[:match_server_addr], match_server_credentials)
    tournament_channel  = create_channel(@config[:tournament_server_addr], tournament_server_credentials)

    @user_stub          = User::Stub.new(user_channel)
    @match_stub         = Match::Stub.new(match_channel)
    @tournament_stub    = Tournament::Stub.new(tournament_channel)

    @request_mapping = {
      UserService::RegisterUserRequest                  => { stub: @user_stub, method: :register_user },
      UserService::GetUserProfileRequest                => { stub: @user_stub, method: :get_user_profile },
      UserService::GetUserStatusRequest                 => { stub: @user_stub, method: :get_user_status },
      MatchService::GetUserMatchesRequest               => { stub: @match_stub, method: :get_user_matches },
      TournamentService::GetUserTournamentsRequest      => { stub: @tournament_stub, method: :get_user_tournaments },
      UserService::DeleteAccountRequest                 => { stub: @user_stub, method: :delete_account },
      UserService::GetPrivateProfileRequest             => { stub: @user_stub, method: :get_private_profile },
      UserService::UpdateProfileRequest                 => { stub: @user_stub, method: :update_profile },
      UserService::UpdatePasswordRequest                => { stub: @user_stub, method: :update_password },
      UserService::RequestPasswordResetRequest          => { stub: @user_stub, method: :request_password_reset },
      UserService::CheckPasswordResetTokenRequest       => { stub: @user_stub, method: :check_password_reset_token },
      UserService::ResetPasswordRequest                 => { stub: @user_stub, method: :reset_password },
      UserService::UpdateEmailRequest                   => { stub: @user_stub, method: :update_email },
      UserService::VerifyEmailRequest                   => { stub: @user_stub, method: :verify_email },
      UserService::CheckEmailVerificationTokenRequest   => { stub: @user_stub, method: :check_email_verification_token },
      UserService::Enable2FARequest                     => { stub: @user_stub, method: :enable_2fa },
      UserService::Get2FAStatusRequest                  => { stub: @user_stub, method: :get_2fa_status },
      UserService::Disable2FARequest                    => { stub: @user_stub, method: :disable_2fa },
      UserService::Check2FACodeRequest                  => { stub: @user_stub, method: :check_2fa_code },
      UserService::LoginUserRequest                     => { stub: @user_stub, method: :login_user },
      UserService::LogoutUserRequest                    => { stub: @user_stub, method: :logout_user },
      UserService::AddFriendRequest                     => { stub: @user_stub, method: :add_friend },
      UserService::GetFriendsRequest                    => { stub: @user_stub, method: :get_friends },
      UserService::RemoveFriendRequest                  => { stub: @user_stub, method: :remove_friend },
      MatchService::CreateMatchRequest                  => { stub: @match_stub, method: :create_match },
      MatchService::JoinMatchRequest                    => { stub: @match_stub, method: :join_match },
      MatchService::GetMatchRequest                     => { stub: @match_stub, method: :get_match },
      MatchService::LeaveMatchRequest                   => { stub: @match_stub, method: :leave_match },
      TournamentService::CreateTournamentRequest        => { stub: @tournament_stub, method: :create_tournament },
      TournamentService::JoinTournamentRequest          => { stub: @tournament_stub, method: :join_tournament },
      TournamentService::GetTournamentRequest           => { stub: @tournament_stub, method: :get_tournament },
      TournamentService::LeaveTournamentRequest         => { stub: @tournament_stub, method: :leave_tournament },
    }.freeze

  rescue StandardError => e
    raise "Error initializing grpc client: #{e}"
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
    raise "Error calling grpc method #{method}: #{e}"
  end

  def close
    @logger.info('Closing grpc client')
    [@user_channel, @match_channel, @tournament_channel].each do |channel|
      channel&.close if defined?(channel) && channel.respond_to?(:close)
    end
  end

  private

  def load_credentials(cert_file)
    raise "Certificate file not found: #{cert_file}" unless File.exist?(cert_file)
    @logger.debug("Loading credentials from #{cert_file}")
    GRPC::Core::ChannelCredentials.new(File.read(cert_file))
  rescue StandardError => e
    raise "Failed to load credentials from #{cert_file}: #{e.message}"
  end

  def create_channel(addr, credentials)
    @logger.debug("Creating channel to #{addr}")
    GRPC::Core::Channel.new(addr, nil, credentials)
  rescue StandardError => e
    raise "Failed to create channel to #{addr}: #{e.message}"
  end

end
