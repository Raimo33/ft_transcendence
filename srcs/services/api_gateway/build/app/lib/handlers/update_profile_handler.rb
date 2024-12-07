# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    update_profile_handler.rb                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:07:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class UpdateProfileHandler < BaseHandler
  def call(parsed_request)
    parsed_request = env[OpenapiFirst::REQUEST]

    @grpc_client.update_profile(
      display_name: parsed_request.parsed_params[:display_name],
      avatar:       parsed_request.parsed_params[:avatar],
      build_request_metadata(parsed_request)
    )
    
    [204, {}, []]
  end
end