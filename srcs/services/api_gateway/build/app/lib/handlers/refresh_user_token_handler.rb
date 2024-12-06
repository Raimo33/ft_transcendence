# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    refresh_user_token_handler.rb                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/01 16:24:02 by craimond          #+#    #+#              #
#    Updated: 2024/12/06 14:51:58 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'time'
require 'jwt'
require_relative 'base_handler'

class RefreshUserSessionTokenHandler < BaseHandler
  def call(env)
    response = @grpc_client.refresh_user_session_token(build_request_metadata(env))

    headers = {
      'Set-Cookie' => build_refresh_token_cookie_header(response.refresh_token),
    }

    body = {
      session_token: response.session_token
    }

    [200, headers, [JSON.generate(body)]]
  end
end