require 'grpc'
require_relative '../proto/user_services_pb'
require_relative '../proto/match_services_pb'
require_relative '../proto/tournament_services_pb'

class GrpcClient
  def initialize
    @user_stub = User::UserService::Stub.new('user-service:50051', :this_channel_is_insecure)
    @match_stub = Match::MatchService::Stub.new('match-service:50051', :this_channel_is_insecure)
    @tournament_stub = Tournament::TournamentService::Stub.new('tournament-service:50051', :this_channel_is_insecure)
  end

  def call_user_service(method, request)
    @user_stub.send(method, request)
  end

  def call_match_service(method, request)
    @match_stub.send(method, request)
  end

  def call_tournament_service(method, request)
    @tournament_stub.send(method, request)
  end
end
