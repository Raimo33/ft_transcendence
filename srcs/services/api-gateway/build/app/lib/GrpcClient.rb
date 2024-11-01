# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    GrpcClient.rb                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/29 14:29:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/01 15:09:34 by craimond         ###   ########.fr        #
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
    
    user_channel       = GRPC::Core::Channel.new($USER_GRPC_SERVER_ADDR, options, user_server_credentials)
    match_channel      = GRPC::Core::Channel.new($MATCH_GRPC_SERVER_ADDR, options, match_server_credentials)
    tournament_channel = GRPC::Core::Channel.new($TOURNAMENT_GRPC_SERVER_ADDR, options, tournament_server_credentials)  
    
    @user_stub       = Users::Stub.new(user_channel)
    @match_stub      = Match::Stub.new(match_channel)
    @tournament_stub = Tournament::Stub.new(tournament_channel)
  rescue => Errno::ENOENT, Errno::EACCES, Errno::EISDIR
    #TODO handle file errors
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
