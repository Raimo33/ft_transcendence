# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    leave_match_handler.rb                             :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 19:17:33 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:30:10 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class LeaveMatchHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    response = @grpc_client.leave_match(
      match_id: parsed_request.parsed_params['match_id'],
      metadata
    )
    
    [204, {}, []]
  end
  
end