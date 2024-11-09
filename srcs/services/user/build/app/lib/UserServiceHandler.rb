# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    UserServiceHandler.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 20:01:35 by craimond          #+#    #+#              #
#    Updated: 2024/11/09 19:36:43 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require 'async'
require 'email_validator'
require_relative './modules/Logger'
require_relative './modules/ConfigLoader'
require_relative '../proto/user_service_pb'

class UserServiceHandler < UserService::Service
  include Logger
  include ConfigLoader
  include EmailValidator

  def initialize(grpc_client)
    @grpc_client = grpc_client
    @logger = Logger.logger
    @config = ConfigLoader.config
  end

  def register_user(request, _metadata)
    @logger.debug("Received registration request: #{request.inspect}")

    required_fields = [request.email, request.password, request.display_name]
    return UserService::RegisterUserResponse.new(status_code: 400) unless required_fields.all?

    Async do |task|
      task.async { check_email(request.email) }
      task.async { check_password(request.password) }
      check_display_name(request.display_name)
      check_avatar(request.avatar) if request.avatar
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

  def check_email(email)
    @logger.debug("Checking email: #{email}")
    check_email_format(email)
    check_email_domain(email)    
  end

  def check_email_format(email)
    raise 'Invalid email format or blacklisted domain' unless EmailValidator.valid?(email, mx: false)
  end
    
  def check_email_domain(email)
    domain = email.split('@').last
    response = @grpc_client.call(UserAuthService::CheckDomainRequest.new(domain: domain))
    raise 'Invalid email domain' unless response&.is_allowed
  end

  def check_display_name(display_name)
    max_length                = @config[:display_name_max_length]
    min_length                = @config[:display_name_min_length]
    allowed_format            = /\A[a-zA-Z0-9_ ]+\z/
    @display_name_bad_words ||= File.readlines(@config[:display_name_bad_words_file]).map(&:strip).map(&:downcase)

    raise 'Invalid display name length' unless request.display_name.length.between?(min_length, max_length)
    raise 'Invalid display name format' unless display_name.match?(allowed_format)

    prohibited_words.each do |word|
      raise 'Invalid display name' if display_name.downcase.include?(word)
    end
  end

  def check_password(password)
    #TODO check password format
  end

  def check_avatar(avatar)
    #TODO formato + size
  end

  def hash_password(password)
    #TODO hash password (auth? async?)
  end

end