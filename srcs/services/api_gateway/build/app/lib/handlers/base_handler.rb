# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    base_handler.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:38 by craimond          #+#    #+#              #
#    Updated: 2024/11/23 17:49:45 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'grpc_client'

class BaseHandler
  def initialize
    @grpc_client   = GrpcClient.instance
  end

  protected

  def json_response(data, status: 200)
    [
      status,
      { 'Content-Type' => 'application/json' },
      [data.to_json]
    ]
  end

end