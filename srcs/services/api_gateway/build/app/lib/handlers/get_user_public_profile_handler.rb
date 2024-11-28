# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_user_public_profile_handler.rb                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/11/24 17:53:51 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetUserPublicProfileHandler < BaseHandler
  def call(params, requesting_user_id)
    grpc_request = User::GetUserPublicProfileRequest.new(params)
    metadata = build_request_metadata(requesting_user_id)
    response = @grpc_client.stubs[:user].get_user_public_profile(grpc_request, metadata)
    build_response_json(response)
  end
end