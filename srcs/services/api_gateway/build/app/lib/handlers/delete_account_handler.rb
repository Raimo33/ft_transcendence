# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    delete_account_handler.rb                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 17:01:34 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class DeleteAccountHandler < BaseHandler
  def call(params, requester_user_id)
    grpc_request = Google::Protobuf::Empty.new
    metadata = build_request_metadata(requester_user_id)
    @grpc_client.stubs[:user].delete_account(grpc_request, metadata)
    
    [204, {}, []]
  end
end