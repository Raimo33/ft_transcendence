# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    base_handler.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:38 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 22:02:07 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'grpc_client'
require_relative 'jwt_validator'
require 'json'
require 'openapi_first'

class BaseHandler

  def initialize
    @grpc_client    = GrpcClient.instance
    @jwt_validator  = JwtValidator.instance
  end

  protected

  def build_request_metadata(env)
    parsed_request = env[OpenapiFirst::REQUEST]
    session_token  = parsed_request.parsed_headers['Authorization'].split(' ').last
    refresh_token  = parsed_request.parsed_cookies['refresh_token']

    {
      'request_id'        => env['HTTP_X_REQUEST_ID'],
      'requester_user_id' => env['REQUESTER_USER_ID'],
      'session_token'     => session_token,
      'refresh_token'     => refresh_token,
    }.compact
  end

  def build_refresh_token_cookie_header(refresh_token)
    #TODO decode token tramite AuthService per ottenere il remember_me e l'exp
    cookie_ttl = decoded_token[0]["remember_me"] ? Time.at(decoded_token[0]["exp"] - 60) : 0

    "refresh_token=#{refresh_token}; Expires=#{cookie_ttl.httpdate}; Path=/; Secure; HttpOnly; SameSite=Strict"
  end

end