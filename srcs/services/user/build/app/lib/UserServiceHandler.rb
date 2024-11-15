# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    UserAPIGatewayServiceHandler.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 20:01:35 by craimond          #+#    #+#              #
#    Updated: 2024/11/12 12:37:40 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "grpc"
require "async"
require "email_validator"
require_relative "ConfigLoader"
require_relative "ConfigurableLogger"
require_relative "../proto/user_pb"
require_relative "../proto/auth_user_pb"
require_relative "../proto/db_gateway_user_pb"

class UserAPIGatewayServiceHandler < UserAPIGatewayService::Service
  include EmailValidator

  def initialize(grpc_client)
    @grpc_client = grpc_client
    @logger = ConfigurableLogger.instance.logger
    @config = ConfigLoader.config

    @db_prepared_stetements = init_db_prepared_statements
  end

  def register_user(request, _metadata)
    @logger.debug("Received '#{__method__}' request: #{request.inspect}")

    required_fields = [request.email, request.password, request.display_name]
    return UserAPIGatewayService::RegisterUserResponse.new(status_code: 400) unless required_fields.all?

    Async do |task|
      task.async { check_email(request.email) }
      task.async { check_password(request.password) }
      check_display_name(request.display_name)
      check_avatar(request.avatar) if request.avatar
    rescue StandardError => e
      return UserAPIGatewayService::RegisterUserResponse.new(status_code: 400)
    ensure
      task.stop
    end

    hashed_password = nil
    Async do |task|
      email = request.email
      task.async { hashed_password = hash_password(request.password) }
      display_name = request.display_name
      avatar = compress_avatar(request.avatar) if request.avatar
    ensure
      task.stop
    end

    register_user = #TODO chiamare il prepared statement corrispondente

    db_response = @grpc_client.db_gateway.execute_prepared(register_user)

    status_code = 
    user_id = 

    UserService::RegisterUserResponse.new(status_code: status_code, user_id: user_id)
  rescue StandardError => e
    @logger.error("Failed to register user: #{e}")
    UserService::RegisterUserResponse.new(status_code: 500, user_id: nil)
  end
  
  private
    
  def init_db_prepared_statements
    query_templates = {
      register_user: "INSERT INTO users (email, psw, display_name, avatar) VALUES ($1, $2, $3, $4) RETURNING id",
      get_user_profile: "SELECT * FROM user_profiles WHERE user_id = $1",
      get_user_status: "SELECT current_status FROM user_profiles WHERE user_id = $1"
      # Add more query templates here
    }
  
    {}.tap do |prepared_statements|
      query_templates.each do |name, query|
        prepared_statement = DBGatewayUserService::Query.new(query)
        response = @grpc_client.db_gateway.prepare_statement(prepared_statement)

        raise "Failed to prepare statement: #{name}" unless response&.statement_name

        prepared_statements[name] = response.statement_name
      end
    end
  rescue StandardError => e
    raise "Failed to prepare statements: #{e}"
  end
  

  def check_email(email)
    @logger.debug("Checking email: #{email}")
    check_email_format(email)
    check_email_domain(email)    
  end

  def check_email_format(email)
    raise "Invalid email format or blacklisted domain" unless EmailValidator.valid?(email, mx: false)
  end
    
  def check_email_domain(email)
    domain = email.split('@').last
    response = @grpc_client.call(AuthUserService::CheckDomainRequest.new(domain: domain))
    raise "Invalid email domain" unless response&.is_allowed
  end

  def check_password(password)
    @psw_format           ||= create_regex_format(@config[:password][:min_length], @config[:password][:max_length], @config[:password][:charset], @config[:password][:policy])
    @psw_banned_passwords ||= load_words(@config[:password][:banned_passwords_file]).map(&:downcase).freeze

    raise "Invalid password format" unless @psw_format =~ password
    @psw_banned_passwords.each do |banned_password|
      raise "Invalid password" if password == banned_password
    end
  end

  def check_display_name(display_name)
    @dn_format       ||= crete_regex_format(@config[:display_name][:min_length], @config[:display_name][:max_length], @config[:display_name][:charset], @config[:display_name][:policy])
    @dn_banned_words ||= load_words(@config[:display_name][:banned_words_file]).map(&:downcase).freeze

    raise "Invalid display name format" unless @dn_format =~ display_name
    @banned_words.each do |word|
      raise "Invalid display name" if display_name.downcase.include?(word)
    end
  end

  def check_avatar(avatar)
    avatar_decoded = Base64.decode64(request.avatar)
    avatar_image = MiniMagick::Image.read(avatar_decoded)

    raise "Invalid avatar type" unless @config[:avatar][:allowed_types].include?(image.mime_type)
    raise "Avatar size exceeds maximum limit" if avatar.size > @config[:avatar][:max_size]
    raise "Avatar dimensions exceed limit" if image.width > @config[:avatar][:max_dimensions][:width] || image.height > @config[:avatar][:max_dimensions][:height]
  end

  def hash_password(password)
    response = @grpc_client.call(AuthUserService::HashPasswordRequest.new(password: password))
    response&.hashed_password
  end

  def compress_avatar(avatar)
    avatar_decoded = Base64.decode64(avatar)
    avatar_image = MiniMagick::Image.read(avatar_decoded)
    
    avatar_image.format(@config[:avatar][:standard_format])
    avatar_image.to_blob
  end

  def load_words(file)
    File.readlines(file).map { |line| line.strip.chomp }
  rescue StandardError => e
    @logger.error("Failed to load words from file #{file}: #{e}")
  end

  def create_regex_format(min_length, max_length, charset, policy)
    length_regex = "^.{#{min_length},#{max_length}}$"

    lowercase_pattern  = "[#{charset[:lowercase]}]"
    uppercase_pattern  = "[#{charset[:uppercase]}]"
    digits_pattern     = "[#{charset[:digits]}]"
    special_pattern    = "[#{charset[:special]}]"

    min_uppercase    = "(?=(.*#{uppercase_pattern}){#{policy[:min_uppercase]},})"
    min_lowercase    = "(?=(.*#{lowercase_pattern}){#{policy[:min_lowercase]},})"
    min_digits       = "(?=(.*#{digits_pattern}){#{policy[:min_digits]},})"
    min_special      = "(?=(.*#{special_pattern}){#{policy[:min_special]},})"

    final_regex = "^#{length_regex}#{min_uppercase}#{min_lowercase}#{min_digits}#{min_special}$"

    final_regex
  end

end