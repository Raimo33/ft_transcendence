# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logout_user_handler.rb                             :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/01 14:46:51 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:07:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class LogoutUserHandler < BaseHandler
  def call(parsed_request)
    @grpc_client.logout_user(build_request_metadata(parsed_request))
    
    [204, {}, []]
  end
end