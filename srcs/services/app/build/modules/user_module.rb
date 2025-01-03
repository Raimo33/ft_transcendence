# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    user_module.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/03 12:07:04 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 18:53:44 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'jwt'
require 'singleton'
require 'resolv'
require 'email_validator'
require 'mini_magick'
require 'base64'
require 'rqrcode'
require 'chunky_png'
require_relative '../shared/config_handler'
require_relative '../shared/pg_client'
require_relative '../shared/exceptions'
require_relative 'auth_module'

class UserModule
  include Singleton
  
  def initialize
    @config = ConfigHandler.instance.config.fetch(:user)
    @pg_client = PGClient.instance
    @memcached_client = MemcachedClient.instance

    @auth_module = AuthModule.instance

    @pg_client.prepare_statements(PREPARED_STATEMENTS)
    @default_avatar = load_default_avatar
  end

  def check_email(email)
    domain = email.split('@').last

    domain_task = Async { @auth_module.check_domain(email) }
    raise BadRequest.new("Invalid email format") unless EmailValidator.valid?(email, mx: false, domain: false)

    domain_task.wait
  rescue EmailValidator::ValidationError
    raise BadRequest.new("Invalid email format")
  ensure
    domain_task&.stop
  end

  def check_password(password)
    psw_config = @config.fetch(:password)
    @psw_format ||= create_regex_format(
      psw_config.fetch(:min_length),
      psw_config.fetch(:max_length),
      psw_config.fetch(:charset),
      psw_config.fetch(:policy)
    )

    raise BadRequest.new("Invalid password format") unless password.match?(@psw_format)
  end

  def check_display_name(display_name)
    dn_config = @config.fetch(:display_name)
    @dn_format ||= create_regex_format(
      dn_config.fetch(:min_length),
      dn_config.fetch(:max_length),
      dn_config.fetch(:charset),
      dn_config.fetch(:policy)
    )

    raise BadRequest.new("Invalid display name format") unless display_name.match?(@dn_format)
  end

  def check_avatar(avatar)
    avatar_decoded = Base64.decode64(avatar)
    avatar_image = MiniMagick::Image.read(avatar_decoded)

    raise BadRequest.new("Invalid avatar type") unless @config.dig(:avatar, :allowed_types).include?(avatar_image.mime_type)
    raise BadRequest.new("Avatar size exceeds maximum limit") if avatar_image.size > @config.dig(:avatar, :max_size)
  rescue Base64::Error
    raise BadRequest.new("Invalid avatar format")
  rescue MiniMagick::Error
    raise BadRequest.new("Invalid or corrupted avatar image file")
  end

  def compress_avatar(avatar)
    avatar_decoded = Base64.decode64(avatar)
    avatar_image = MiniMagick::Image.read(avatar_decoded)
    
    avatar_image.format(@config.dig(:avatar, :format))
    avatar_image.to_blob
  rescue MiniMagick::Invalid
    raise BadRequest.new("Invalid or corrupted avatar image file")
  rescue MiniMagick::Error
    raise InternalServerError.new("Error while compressing avatar")
  rescue Base64::Error
    raise BadRequest.new("Invalid avatar format")
  end

  def decompress_avatar(avatar)
    avatar_image = MiniMagick::Image.read(avatar)

    avatar_image.format(@config.dig(:avatar, :format))
    processed_avatar_binary_data = avatar_image.to_blob
    
    "data:image/#{avatar_image.type.downcase};base64,#{Base64.strict_encode64(processed_avatar_binary_data)}"
  rescue MiniMagick::Error
    raise InternalServerError.new("Error while decompressing avatar")
  end

  def generate_qr_code(uri)
    qr_code = RQRCode::QRCode.new(uri)

    png = qr_code.as_png(
      bit_depth: 1,
      border_modules: 4,
      color_mode: ChunkyPNG::COLOR_GRAYSCALE,
      color: 'black',
      file: nil,
      fill: 'white',
      module_px_size: 6,
      resize_exactly_to: false,
      resize_gte_to: false
    )

    "data:image/png;base64,#{Base64.strict_encode64(png.to_s)}"
  rescue RQRCode::QRCodeRunTimeError
    raise InternalServerError.new("Error while generating QR code")    
  end

  def forget_past_sessions(user_id)
    now = Time.now.to_i - @config.dig(:tokens, :invalidation_grace_period)
    @memcached_client.set("token_invalid_before:#{user_id}", now)
  end

  def erase_user_cache(user_id)
    Async do |task|
      task.async { @memcached_client.delete("token_invalid_before:#{user_id}") }
      #TODO other cleanups for keys
    end
    async_context.wait
  ensure
    async_context&.stop
  end

  def generate_session_jwt(user_id, pending_tfa)
    settings = @config.dig(:tokens, :session)

    if pending_tfa
      ttl = settings.fetch(:ttl_pending_tfa)
      auth_level = 1
    else
      ttl = settings.fetch(:ttl)
      auth_level = 2
    end

    @auth_module.generate_jwt(
      identifier:  user_id,
      ttl:         ttl,
      custom_claims: {
        auth_level: auth_level
      }
    )
  end

  def generate_refresh_jwt(user_id, remember_me)
    @auth_module.generate_jwt(
      identifier: user_id,
      ttl: @config.dig(:tokens, :refresh, :ttl),
      custom_claims: {
        remember_me: remember_me
      }
    )
  end

  def build_refresh_token_cookie_header(refresh_token, remember_me)
    if remember_me
      cookie_expire_after = @config.dig(:tokens, :refresh, :expire_after)
      "refresh_token=#{refresh_token}; Expires=#{cookie_expire_after.httpdate}; Path=/; Secure; HttpOnly; SameSite=Strict"
    else
      "refresh_token=#{refresh_token}; Path=/; Secure; HttpOnly; SameSite=Strict"
    end
  end

  private

  PREPARED_STATEMENTS = {
    insert_user: <<~SQL
      INSERT INTO Users (email, psw, display_name, avatar)
      VALUES ($1, $2, $3, $4)
      RETURNING id
    SQL
    get_public_profile: <<~SQL
      SELECT *
      FROM UserPublicProfiles
      WHERE id = $1
    SQL
    get_status: <<~SQL
      SELECT current_status
      FROM UserProfiles
      WHERE id = $1
    SQL
    delete_user: <<~SQL
      DELETE FROM Users 
      WHERE id = $1
    SQL
    get_private_profile: <<~SQL
      SELECT *
      FROM UserPrivateProfiles
      WHERE id = $1
    SQL
    update_profile: <<~SQL
      UPDATE Users
      SET 
        display_name = COALESCE($1, display_name),
        avatar = COALESCE($2, avatar)
      WHERE id = $3
    SQL
    enable_tfa: <<~SQL
      UPDATE Users 
      SET tfa_status = true, 
          tfa_secret = $2 
      WHERE id = $1 AND tfa_status = false
    SQL
    delete_tfa: <<~SQL
      UPDATE Users
      SET tfa_status = false, tfa_secret = NULL
      WHERE id = $1 AND tfa_status = true
    SQL
    get_tfa: <<~SQL
      SELECT tfa_secret, tfa_status
      FROM Users
      WHERE id = $1
    SQL
    get_login_data: <<~SQL
      SELECT id, psw, tfa_status, current_status
      FROM Users
      WHERE email = $1
    SQL
    update_user_status: <<~SQL
      UPDATE UserProfiles
      SET current_status = $2
      WHERE id = $1
    SQL
    check_friendship: <<~SQL
      SELECT status
      FROM Friendships
      WHERE user_id_1 = $1 AND user_id_2 = $2
    SQL
    insert_friend_request: <<~SQL        
      INSERT INTO Friendships (user_id_1, user_id_2)
      VALUES ($1, $2)
    SQL
    update_friendship: <<~SQL
      UPDATE Friendships
      SET status = $3
      WHERE user_id_1 = $1 AND user_id_2 = $2
    SQL
    get_friends: <<~SQL
      SELECT friend_id
      FROM UserFriendsChronologicalMatView
      WHERE user_id = $1 AND (created_at, friend_id) < ($2, $3)
      ORDER BY created_at DESC, friend_id DESC
      LIMIT $4
    SQL
    delete_friendship: <<~SQL
      DELETE FROM Friendships
      WHERE user_id_1 = $1 AND user_id_2 = $2
    SQL
  }.freeze

  def load_default_avatar
    default_avatar_path = File.join(File.dirname(__FILE__), @config.dig(:avatar, :default_avatar))
    avatar = File.read(default_avatar_path)

    Base64.encode64(avatar)
  rescue Errno::ENOENT
    raise InternalServerError.new("Default avatar not found")
  rescue Base64::Error
    raise InternalServerError.new("Error while encoding default avatar")
  end

  def create_regex_format(min_length, max_length, charset, policy)
    length_regex = "^.{#{min_length},#{max_length}}$"

    lowercase_pattern  = "[#{charset[:lowercase]}]"
    uppercase_pattern  = "[#{charset[:uppercase]}]"
    digits_pattern     = "[#{charset[:digits]}]"
    special_pattern    = "[#{charset[:special]}]"

    min_uppercase  = "(?=(.*#{uppercase_pattern}){#{policy[:min_uppercase]},})"
    min_lowercase  = "(?=(.*#{lowercase_pattern}){#{policy[:min_lowercase]},})"
    min_digits     = "(?=(.*#{digits_pattern}){#{policy[:min_digits]},})"
    min_special    = "(?=(.*#{special_pattern}){#{policy[:min_special]},})"

    "^#{length_regex}#{min_uppercase}#{min_lowercase}#{min_digits}#{min_special}$"
  end

end