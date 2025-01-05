# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_context.rb                                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/03 21:22:14 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 21:38:08 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'securerandom'

class RequestContext

  def self.request_id
    Thread.current[:request_id] ||= SecureRandom.uuid
  end

  def self.request_id=(id)
    Thread.current[:request_id] = id
  end

  def self.session_token
    Thread.current[:session_token]
  end

  def self.session_token=(token)
    Thread.current[:session_token] = token
  end

  def self.refresh_token
    Thread.current[:refresh_token]
  end

  def self.refresh_token=(token)
    Thread.current[:refresh_token] = token
  end

  def self.clear
    CONTEXT_KEYS.each do |key|
      Thread.current[key] = nil
    end
  end

  private

  CONTEXT_KEYS = %i[request_id session_token refresh_token]

end
