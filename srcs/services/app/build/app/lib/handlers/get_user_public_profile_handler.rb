# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_user_public_profile_handler.rb                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:29:51 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetUserPublicProfileHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    response = @grpc_client.get_user_public_profile(
      user_id: parsed_request.parsed_params['user_id'],
      metadata
    )
    
    body = {
      id:           response.user_id,
      display_name: response.display_name,
      avatar:       response.avatar,
      status:       response.status,
      created_at:   response.created_at.seconds,
    }

    [200, {}, [JSON.generate(body)]]
  end
  
end