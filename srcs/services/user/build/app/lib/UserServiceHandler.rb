# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    UserServiceHandler.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 20:01:35 by craimond          #+#    #+#              #
#    Updated: 2024/11/08 23:19:08 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative './modules/Logger'
require_relative './modules/ConfigLoader'
require_relative '../proto/user_service_pb'

class UserServiceHandler < UserService::Service

  def initialize(grpc_client)
    @grpc_client = grpc_client
    @logger = Logger.logger
  end

  def register_user(request, _metadata)
    @logger.debug("Received registration request: #{request.inspect}")

    email = request.email
    password = request.password
    display_name = request.display_name
    avatar = request.avatar

    return UserService::RegisterUserResponse.new(status_code: 400) unless email && password && display_name

    response = @grpc_client. #TODO chiamare il servizio query che converte richiesta in query SQL
    UserService::RegisterUserResponse.new(status_code: 
    rescue StandardError => e
      @logger.error("Failed to register user: #{e}")
      UserService::RegisterUserResponse.new(status_code: 500)
    end

  end

end