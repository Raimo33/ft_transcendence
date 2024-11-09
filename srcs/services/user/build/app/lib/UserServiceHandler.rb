# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    UserServiceHandler.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 20:01:35 by craimond          #+#    #+#              #
#    Updated: 2024/11/09 10:49:55 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'async'
require 'email_validator'
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

    required_fields = [request.email, request.password, request.display_name]
    return UserService::RegisterUserResponse.new(status_code: 400) unless required_fields.all?

    Async do |task|
      task.async { check_email }
      task.async { check_password }
      check_display_name
      check_avatar
    rescue StandardError => e
      @logger.error("Failed to validate user data: #{e}")
      return UserService::RegisterUserResponse.new(status_code: 400)
    ensure
      task.stop
    end

    response = @grpc_client. #TODO chiamare il servizio query che converte richiesta in query SQL
    UserService::RegisterUserResponse.new(status_code: response 
    rescue StandardError => e
      @logger.error("Failed to register user: #{e}")
      UserService::RegisterUserResponse.new(status_code: 500)
    end
  end

  private

  def check_email
    #TODO formato + dns resolution (async tramite auth service con gem 'resolv')
    
  end

  def check_display_name
    #TODO formato + lunghezza + parole vietate
  end

  def check_password
    #TODO password policy
  end

  def check_avatar
    #TODO formato + size
  end

  def hash_password
    #TODO hash password (auth? async?)
  end

end