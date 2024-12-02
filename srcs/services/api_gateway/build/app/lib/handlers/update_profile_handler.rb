# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    update_profile_handler.rb                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:35:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class UpdateProfileHandler < BaseHandler
  def call(request, requester_user_id)
    grpc_request = User::UpdateProfileRequest.new(request.params)
    metadata = build_request_metadata(request, requester_user_id)
    @grpc_client.stubs[:user].update_profile(grpc_request, metadata)
    
    [204, {}, []]
  end
end