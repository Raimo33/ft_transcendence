# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    get_user_private_profile_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:07:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class GetUserPrivateProfileHandler < BaseHandler
  def call(parsed_request)
    response = @grpc_client.get_user_private_profile(build_request_metadata(parsed_request))
    
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