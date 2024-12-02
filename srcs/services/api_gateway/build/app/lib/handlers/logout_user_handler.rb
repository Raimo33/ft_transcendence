# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logout_user_handler.rb                             :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/01 14:46:51 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:35:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class LogoutUserHandler < BaseHandler
  def call(request, requester_user_id)
    metadata = build_request_metadata(request, requester_user_id)
    @grpc_client.stubs[:user].logout_user(metadata)
    
    [204, {}, []]
  end
end