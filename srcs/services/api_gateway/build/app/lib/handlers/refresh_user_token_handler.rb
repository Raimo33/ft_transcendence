# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    refresh_user_token_handler.rb                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/01 16:24:02 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:30:44 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'time'
require 'jwt'
require_relative 'base_handler'

class RefreshUserSessionTokenHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    response = @grpc_client.refresh_user_session_token(metadata)

    body = {
      session_token: response.session_token
    }

    [200, {}, [JSON.generate(body)]]
  end
  
end