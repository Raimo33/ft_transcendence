# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_user_private_profile_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 18:20:25 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetUserPrivateProfileHandler < BaseHandler
  def call(env)
    response = @grpc_client.get_user_private_profile(build_request_metadata(env))
    
    body = {
      id:           response.id,
      display_name: response.display_name,
      avatar:       response.avatar,
      status:       response.status,
      email:        response.email,
      tfa_status:   response.tfa_status,
    }

    [200, {}, [JSON.generate(body)]]
  end
end