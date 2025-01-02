# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    jwt_validator.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/09 19:01:54 by craimond          #+#    #+#              #
#    Updated: 2025/01/02 23:15:00 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'singleton'
require_relative 'memcached_client'

class JwtValidator
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    @private_key = OpenSSL::PKey::RSA.new(@config.dig(:jwt, :private_key))
    @memcached_client = MemcachedClient.instance
  end

  def token_revoked?(sub, iat)
    token_invalid_before = @memcached_client.get("token_invalid_before:#{sub}")
    return true if token_invalid_before.nil?

    iat < token_invalid_before.to_i
  end
end