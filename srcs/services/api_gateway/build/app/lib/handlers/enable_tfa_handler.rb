# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    enable_tfa_handler.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:44 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 18:19:43 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'base_handler'

class EnableTFAHandler < BaseHandler
  def call(env)
    response = @grpc_client.enable_tfa(build_request_metadata(env))
    
    body = {
      tfa_secret:   response.tfa_secret,
      tfa_qr_code:  response.tfa_qr_code
    }

    [200, {}, [JSON.generate(body)]]
  end
end