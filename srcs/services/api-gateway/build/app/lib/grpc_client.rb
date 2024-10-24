require 'grpc'
require_relative '../proto/user_services_pb'
require_relative '../proto/match_services_pb'
require_relative '../proto/tournament_services_pb'

class GrpcClient
  def initialize
    @user_stub = create_stub($USER_SERVER_CERT, 'user.corenet:50051', User::UserService::Stub)
    @match_stub = create_stub($MATCH_SERVER_CERT, 'match.corenet:50051', Match::MatchService::Stub)
    @tournament_stub = create_stub($TOURNAMENT_SERVER_CERT, 'tournament.corenet:50051', Tournament::TournamentService::Stub)
  end

  private

  def create_stub(cert_file, server_address, service_stub)
    cert = read_certificate(cert_file)
    service_stub.new(server_address, cert)
  end

  def read_certificate(cert_file)
    begin
      GRPC::Core::ChannelCredentials.new(File.read(cert_file))
    rescue Errno::ENOENT
      raise "Certificate file not found: #{cert_file}"
    rescue Errno::EACCES
      raise "Permission denied when accessing: #{cert_file}"
    rescue StandardError => e
      raise "Error reading certificate file #{cert_file}: #{e.message}"
    end
  end
end

