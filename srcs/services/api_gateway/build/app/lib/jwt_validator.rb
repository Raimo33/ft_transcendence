# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    jwt_validator.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/01 19:14:39 by craimond          #+#    #+#              #
#    Updated: 2024/11/23 17:06:32 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "jwt"
require "singleton"
require_relative "ConfigHandler"
require_relative "GrpcClient"

class JwtValidator
  include Singleton

  def initialize
    @grpc_client = GrpcClient.instance
    @config = ConfigHandler.instance.config
    @public_keys = {}
    @last_fetched = nil
  end

  def validate_token(token, auth_level)
    decoded_token = decode_token(token)
    return false unless decoded_token
    
    claims = decoded_token[0]
    return false unless validate_claims(claims)
    return false unless claims["auth_level"].to_i >= auth_level

    true
  end

  def get_subject(token)
    decoded_token = decode_token(token)
    return false unless decoded_token

    decoded_token[0]["sub"]
  end

  private

  def decode_token(token)
    header = JWT.decode_jwt_header(token)
    key_id = header['kid']
    return false unless key_id

    public_key = get_public_key(key_id)
    return false unless public_key

    JWT.decode(token, public_key, true, {
      algorithm:  @config[:jwt][:algorithm],
      verify_iat: true,
      verify_exp: true,
      verify_aud: true,
      aud:        @config[:jwt][:audience],
      leeway:     @config[:jwt][:clock_skew]
    })
  end

  def get_public_key(key_id)
    refresh_keys if should_refresh_keys?
    @public_keys[key_id]
  end

  def refresh_keys
    response = @grpc_client.stubs[:auth].get_public_keys(Auth::GetPublicKeysRequest.new)
    
    @public_keys.clear
    response.public_keys.each do |key|
      @public_keys[key.id] = OpenSSL::PKey::RSA.new(key.key)
    end
    
    @last_fetched = Time.now
  end

  def should_refresh_keys?
    return true if @last_fetched.nil?
    Time.now - @last_fetched >= @config[:jwt][:key_refresh_interval]
  end

  def validate_claims(claims)
    return false unless claims["exp"] && claims["iat"] && claims["aud"]
    
    now = Time.now.to_i
    skew = @config[:jwt][:clock_skew]

    claims["exp"] + skew > now &&
    claims["iat"] - skew < now &&
    claims["aud"] == @config[:jwt][:audience]
  end
end