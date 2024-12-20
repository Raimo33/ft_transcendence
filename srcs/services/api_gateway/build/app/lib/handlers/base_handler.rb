# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    base_handler.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:38 by craimond          #+#    #+#              #
#    Updated: 2024/12/20 13:09:38 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'json'
require 'openapi_first'
require_relative 'grpc_client'
require_relative '../request_context'

class BaseHandler

  def initialize
    @grpc_client    = GrpcClient.instance
  end

  protected

  def build_request_metadata(parsed_request)
    session_token  = parsed_request.parsed_headers['Authorization'].split(' ').last
    refresh_token  = parsed_request.parsed_cookies['refresh_token']

    {
      'request_id'        => RequestContext.request_id,
      'requester_user_id' => RequestContext.requester_user_id,
      'session_token'     => session_token,
      'refresh_token'     => refresh_token,
    }.compact
  end

  def build_refresh_token_cookie_header(refresh_token)
    decoded_token = @grpc_client.decode_jwt(refresh_token)
    remember_me = decoded_token&.payload&.dig("remember_me")&.bool_value
    exp_timestamp = decoded_token&.payload&.dig("exp")&.number_value

    if remember_me && exp_timestamp
      cookie_expire_after = Time.at(exp_timestamp)
      "refresh_token=#{refresh_token}; Expires=#{cookie_expire_after.httpdate}; Path=/; Secure; HttpOnly; SameSite=Strict"
    else
      "refresh_token=#{refresh_token}; Path=/; Secure; HttpOnly; SameSite=Strict"
    end
  end

end