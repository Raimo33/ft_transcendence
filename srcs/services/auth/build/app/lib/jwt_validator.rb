# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    jwt_validator.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/09 19:01:54 by craimond          #+#    #+#              #
#    Updated: 2024/12/09 19:07:38 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'singleton'

class JwtValidator
  include Singleton

  def initialize
    @config = ConfigHandler.instance.config
    @private_key = OpenSSL::PKey::RSA.new(@config[:jwt][:private_key])
  end

  private

  def token_revoked?(sub, iat)
    token_invalid_before = @redis_client.get("sub:#{sub}:token_invalid_before")
    return true if token_invalid_before.nil?

    iat < token_invalid_before.to_i
  end
end