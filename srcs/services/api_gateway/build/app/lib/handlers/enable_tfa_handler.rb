# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    enable_tfa_handler.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 19:07:48 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class EnableTFAHandler < BaseHandler
  def call(params, requester_user_id)
    grpc_request = Google::Protobuf::Empty.new
    metadata = build_request_metadata(requester_user_id)
    response = @grpc_client.stubs[:user].enable_tfa(grpc_request, metadata)
    
    [200, {}, [response.to_json]]
  end
end