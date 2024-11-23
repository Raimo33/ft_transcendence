# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Structs.rb                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/28 19:55:38 by craimond          #+#    #+#              #
#    Updated: 2024/11/23 11:59:54 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

module Structs
  ExpectedRequest = Struct.new(
    :allowed_path_params,
    :allowed_query_params,
    :allowed_headers,
    :body_schema,
    :auth_level
  )

  Response  = Struct.new(
    :status_code,
    :headers,
    :body
  )

  Request   = Struct.new(
    :http_method,
    :path,
    :query_params,
    :headers,
    :body,
  )

  Resource  = Struct.new(
    :operation_id,
    :path,
    :expected_request
  )
end