# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    base_handler.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 15:36:38 by craimond          #+#    #+#              #
#    Updated: 2024/11/28 15:10:12 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'grpc_client'

class BaseHandler
  def initialize
    @grpc_client = GrpcClient.instance
  end

  protected

  def build_response_json(data, status = nil)
    status ||= data.empty? ? 204 : 200
    [
      status,
      { 'Content-Type' => 'application/json' },
      [data.to_json]
    ]
  end

  def build_request_metadata(requesting_user_id)
    {
      'x-request-id'          => SecureRandom.uuid,
      'x-requester-user-id'   => requesting_user_id
    }.compact
  end

end