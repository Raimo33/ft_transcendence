# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcClient.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/18 18:27:48 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require_relative "ConfigLoader"
require_relative "ConfigurableLogger"
require_relative "Modules/GrpcClientHandler"
require_relative "../proto/user_api_gateway_pb"
require_relative "../proto/match_api_gateway_pb"
require_relative "../proto/tournament_api_gateway_pb"

class GrpcClient
  include GrpcClientHandler

  def initialize
    @logger.info("Initializing grpc client")
    
    @config   = ConfigLoader.instance.config
    @logger   = ConfigurableLogger.instance.logger
    @channels = {}
    @stubs    = {}

    channel_options = {
      "grpc.compression_algorithm" => "gzip"
    }

    @channels = {
      user:        create_channel(@config[:addresses][:user],       :this_channel_is_insecure, channel_options),
      match:       create_channel(@config[:addresses][:match],      :this_channel_is_insecure, channel_options),
      tournament:  create_channel(@config[:addresses][:tournament], :this_channel_is_insecure, channel_options),
      auth:        create_channel(@config[:addresses][:auth],       :this_channel_is_insecure, channel_options)
    }

    @stubs = {
      :user        => User::Stub.new(@channels[:user]),
      :match       => Match::Stub.new(@channels[:match]),
      :tournament  => Tournament::Stub.new(@channels[:tournament]),
      :auth        => Auth::Stub.new(@channels[:auth])
    }
  rescue StandardError => e
    raise "Failed to initialize grpc client: #{e}"
  ensure
    close
  end

  def close
    @logger.info("Closing gRPC client connections")
    @channels.each_value(&:close)
  end

  def register_user(email, password, display_name, avatar)
    handle_grpc_call do

      grpc_request = User::RegisterUserRequest.new(
        email:        email,
        password:     password,
        display_name: display_name,
        avatar:       avatar
      )

      @stubs[:user].register_user(grpc_request)
    end
  end

  def get_user_profile(requester_user_id, user_id)
    handle_grpc_call do

      grpc_request = User::GetUserProfileRequest.new(
        requester_user_id: requester_user_id,
        user_id:           user_id
      )

      @stubs[:user].get_user_profile(grpc_request)
    end
  end

  def get_user_stauts(user_id)
    handle_grpc_call do

      grpc_request = User::GetUserStatusRequest.new(
        user_id: user_id
      )

      @stubs[:user].get_user_status(grpc_request)
    end
  end

  def get_user_matches(requester_user_id, user_id, limit, offset)
    handle_grpc_call do

      grpc_request = Match::GetUserMatchesRequest.new(
        requester_user_id: requester_user_id,
        user_id:           user_id,
        limit:             limit,
        offset:            offset
      )

      @stubs[:match].get_user_matches(grpc_request)
    end
  end

  def get_user_tournaments(requester_user_id, user_id, limit, offset)
    handle_grpc_call do

      grpc_request = Tournament::GetUserTournamentsRequest.new(
        requester_user_id: requester_user_id,
        user_id:           user_id,
        limit:             limit,
        offset:            offset
      )

      @stubs[:tournament].get_user_tournaments(grpc_request)
    end
  end

  def delete_account(requester_user_id)
    handle_grpc_call do

      grpc_request = User::DeleteAccountRequest.new(
        requester_user_id: requester_user_id
      )

      @stubs[:user].delete_account(grpc_request)
    end
  end

  def get_private_profile(requester_user_id)
    handle_grpc_call do

      grpc_request = User::GetPrivateProfileRequest.new(
        requester_user_id: requester_user_id
      )

      @stubs[:user].get_private_profile(grpc_request)
    end
  end

  def update_profile(requester_user_id, display_name, avatar)
    handle_grpc_call do

      grpc_request = User::UpdateProfileRequest.new(
        requester_user_id:  requester_user_id,
        display_name:       display_name,
        avatar:             avatar
      )

      @stubs[:user].update_profile(grpc_request)
    end
  end

  def update_password(requester_user_id, old_password, new_password)
    handle_grpc_call do

      grpc_request = User::UpdatePasswordRequest.new(
        requester_user_id: requester_user_id,
        old_password:      old_password,
        new_password:      new_password
      )

      @stubs[:user].update_password(grpc_request)
    end
  end

  def update_email
    #TOOD implement
  end

  def enable_2fa(requester_user_id)
    handle_grpc_call do

      grpc_request = User::Enable2FARequest.new(
        requester_user_id: requester_user_id,
      )

      @stubs[:user].enable_2fa(grpc_request)
    end
  end

  def get_2fa_status(requester_user_id)
    handle_grpc_call do

      grpc_request = User::Get2FAStatusRequest.new(
        requester_user_id: requester_user_id
      )

      @stubs[:user].get_2fa_status(grpc_request)
    end
  end

  def disable_2fa(requester_user_id, totp_code)
    handle_grpc_call do

      grpc_request = User::Disable2FARequest.new(
        requester_user_id: requester_user_id,
        totp_code:         totp_code
      )

      @stubs[:user].disable_2fa(grpc_request)
    end
  end

  def check_2fa_code(requester_user_id, totp_code)
    handle_grpc_call do

      grpc_request = User::Check2FACodeRequest.new(
        requester_user_id: requester_user_id,
        totp_code:         totp_code
      )

      @stubs[:user].check_2fa_code(grpc_request)
    end
  end

  def login_user(email, password)
    handle_grpc_call do

      grpc_request = User::LoginUserRequest.new(
        email:    email,
        password: password
      )

      @stubs[:user].login_user(grpc_request)
    end
  end

  def add_friend(requester_user_id, friend_id)
    handle_grpc_call do

      grpc_request = User::AddFriendRequest.new(
        requester_user_id: requester_user_id,
        friend_id:         friend_id
      )

      @stubs[:user].add_friend(grpc_request)
    end
  end

  def get_friends(requester_user_id, limit, offset)
    handle_grpc_call do

      grpc_request = User::GetFriendsRequest.new(
        requester_user_id: requester_user_id,
        limit:             limit,
        offset:            offset
      )

      @stubs[:user].get_friends(grpc_request)
    end
  end

  def remove_friend(requester_user_id, friend_id)
    handle_grpc_call do

      grpc_request = User::RemoveFriendRequest.new(
        requester_user_id: requester_user_id,
        friend_id:         friend_id
      )

      @stubs[:user].remove_friend(grpc_request)
    end
  end

  def create_match(requester_user_id, invited_user_ids)
    handle_grpc_call do

      grpc_request = Match::CreateMatchRequest.new(
        requester_user_id: requester_user_id,
        invited_user_ids:  invited_user_ids
      )

      @stubs[:match].create_match(grpc_request)
    end
  end

  def join_match(requester_user_id, match_id)
    handle_grpc_call do

      grpc_request = Match::JoinMatchRequest.new(
        requester_user_id: requester_user_id,
        match_id:          match_id
      )

      @stubs[:match].join_match(grpc_request)
    end
  end

  def get_match(requester_user_id, match_id)
    handle_grpc_call do

      grpc_request = Match::GetMatchRequest.new(
        requester_user_id: requester_user_id,
        match_id:          match_id
      )

      @stubs[:match].get_match(grpc_request)
    end
  end

  def leave_match(requester_user_id, match_id)
    handle_grpc_call do

      grpc_request = Match::LeaveMatchRequest.new(
        requester_user_id: requester_user_id,
        match_id:          match_id
      )

      @stubs[:match].leave_match(grpc_request)
    end
  end

  def create_tournament(requester_user_id, invited_user_ids)
    handle_grpc_call do

      grpc_request = Tournament::CreateTournamentRequest.new(
        requester_user_id: requester_user_id,
        invited_user_ids:  invited_user_ids
      )

      @stubs[:tournament].create_tournament(grpc_request)
    end
  end

  def join_tournament(requester_user_id, tournament_id)
    handle_grpc_call do

      grpc_request = Tournament::JoinTournamentRequest.new(
        requester_user_id: requester_user_id,
        tournament_id:     tournament_id
      )

      @stubs[:tournament].join_tournament(grpc_request)
    end
  end

  def get_tournament(requester_user_id, tournament_id)
    handle_grpc_call do

      grpc_request = Tournament::GetTournamentRequest.new(
        requester_user_id: requester_user_id,
        tournament_id:     tournament_id
      )

      @stubs[:tournament].get_tournament(grpc_request)
    end
  end

  def leave_tournament(requester_user_id, tournament_id)
    handle_grpc_call do

      grpc_request = Tournament::LeaveTournamentRequest.new(
        requester_user_id: requester_user_id,
        tournament_id:     tournament_id
      )

      @stubs[:tournament].leave_tournament(grpc_request)
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
