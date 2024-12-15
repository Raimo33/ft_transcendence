# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    logout_user_handler.rb                             :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/01 14:46:51 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:30:35 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class LogoutUserHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    @grpc_client.logout_user(metadata)
    
    [204, {}, []]
  end
  
end