# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    disable_tfa_handler.rb                             :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:29:05 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class DisableTFAHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    @grpc_client.disable_tfa(
      code: parsed_request['tfa_code'],
      metadata
    )
    
    [204, {}, []]
  end
  
end