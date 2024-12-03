# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    delete_account_handler.rb                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 18:19:35 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class DeleteAccountHandler < BaseHandler
  def call(env)
    @grpc_client.delete_account(build_request_metadata(env))
    
    [204, {}, []]
  end
end