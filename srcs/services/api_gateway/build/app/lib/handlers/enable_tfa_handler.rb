# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    enable_tfa_handler.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/15 20:29:17 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class EnableTFAHandler < BaseHandler

  def call(parsed_request)
    metadata = build_request_metadata(parsed_request)
    response = @grpc_client.enable_tfa(metadata)
    
    body = {
      tfa_secret:   response.tfa_secret,
      tfa_qr_code:  response.tfa_qr_code
    }

    [200, {}, [JSON.generate(body)]]
  end
  
end