# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    refresh_user_token_handler.rb                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/01 16:24:02 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 19:08:00 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'time'
require 'jwt'
require_relative 'base_handler'

class RefreshUserTokenHandler < BaseHandler

  def call(params, requester_user_id)
    grpc_request = User::RefreshUserTokenRequest.new(params)
    metadata = build_request_metadata(requester_user_id)
    response = @grpc_client.stubs[:user].refresh_user_token(grpc_request, metadata)

    headers = {
      'Set-Cookie' => build_refresh_token_cookie_header(response.refresh_token),
    }

    body = {
      session_token: response.session_token
    }

    [200, headers, [body.to_json]]
  end
end