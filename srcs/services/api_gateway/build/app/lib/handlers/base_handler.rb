# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    base_handler.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:38 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:34:34 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'grpc_client'
require_relative 'jwt_validator'
require 'json'
require 'openapi_first'

class BaseHandler

  def initialize
    @grpc_client = GrpcClient.instance
    @jwt_validator = JwtValidator.instance
  end

  protected

  def build_request_metadata(request, requester_user_id)
    session_token = @jwt_validator.extract_token(request.headers['Authorization'])
    refresh_token = request.cookies['refresh_token']

    {
      'request_id'        => SecureRandom.uuid,
      'requester_user_id' => requester_user_id,
      'session_token'     => session_token,
      'refresh_token'     => refresh_token,
    }.compact
  end

  def build_refresh_token_cookie_header(refresh_token)
    decoded_token = @jwt_validator.decode_outgoing_refresh_token(refresh_token)
    cookie_ttl = decoded_token[0]["remember_me"] ? Time.at(decoded_token[0]["exp"] - 60) : 0

    "refresh_token=#{refresh_token}; Expires=#{cookie_ttl.httpdate}; Path=/; Secure; HttpOnly; SameSite=Strict"
  end

end