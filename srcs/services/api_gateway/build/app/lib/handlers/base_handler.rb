# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    base_handler.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:38 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 19:15:32 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'grpc_client'

class BaseHandler
  def initialize
    @grpc_client = GrpcClient.instance
    @jwt_validator = JwtValidator.instance
  end

  protected

  def build_request_metadata(requester_user_id)
    {
      'x-request-id'          => SecureRandom.uuid,
      'x-requester-user-id'   => requester_user_id
    }.compact
  end

  def build_refresh_token_cookie_header(refresh_token)
    decoded_token = @jwt_validator.decode_outgoing_refresh_token(refresh_token)
    exp_time = decoded_token[0]["remember_me"] ? Time.at(decoded_token[0]["exp"] - 60).utc.httpdate : 0

    "refresh_token=#{refresh_token}; Expires=#{exp_time}; Path=/; HttpOnly; Secure; SameSite=Strict"
  end

end