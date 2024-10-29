# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcClient.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/10/29 17:02:38 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class GrpcClient
  def initialize
    services = {
      user: {
        cert_file: $USER_SERVER_CERT,
        address: 'user.corenet:50051',
        stub_class: User::UserService::Stub
      },
      match: {
        cert_file: $MATCH_SERVER_CERT,
        address: 'match.corenet:50051',
        stub_class: Match::MatchService::Stub
      },
      tournament: {
        cert_file: $TOURNAMENT_SERVER_CERT,
        address: 'tournament.corenet:50051',
        stub_class: Tournament::TournamentService::Stub
      }
    }

    @stubs = {}
    services.each do |service_name, service_info|
      @stubs[service_name] = create_stub(service_info[:cert_file], service_info[:address], service_info[:stub_class])
  end

  def call(grpc_request)
    #TODO deduce stub and call the method based on grpc_request object
  end

  private

  def create_stub(cert_file, address, stub_class)
    cert = read_certificate(cert_file)
    stub_class.new(address, cert)
  end

  def read_certificate(cert_file)
    begin
      GRPC::Core::ChannelCredentials.new(File.read(cert_file))
    rescue #TODO handle file errors
    end
  end

  def get_stub(method_name)
    @stubs.each do |service_name, stub|
      return stub if stub.class.instance_methods.include?(method_name.to_sym)
    end
    nil
  end

end
