# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcClient.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/01 07:44:54 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class GrpcClient
  def initialize
    user_server_credentials = GRPC::Core::ChannelCredentials.new(File.read($USER_SERVER_CERT))
    match_server_credentials = GRPC::Core::ChannelCredentials.new(File.read($MATCH_SERVER_CERT))
    tournament_server_credentials = GRPC::Core::ChannelCredentials.new(File.read($TOURNAMENT_SERVER_CERT))
    
    options = {
      'grpc.compression_algorithm' => 'gzip'
    }
    
    user_channel       = GRPC::Core::Channel.new('users.corenet:50051', options, user_server_credentials)
    match_channel      = GRPC::Core::Channel.new('match.corenet:50051', options, match_server_credentials)
    tournament_channel = GRPC::Core::Channel.new('tournament.corenet:50051', options, tournament_server_credentials)  
    
    @user_stub       = Users::Stub.new(user_channel)
    @match_stub      = Match::Stub.new(match_channel)
    @tournament_stub = Tournament::Stub.new(tournament_channel)
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
