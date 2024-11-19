# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Structs.rb                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/28 19:55:38 by craimond          #+#    #+#              #
#    Updated: 2024/11/19 18:18:26 by craimond         ###   ########.fr        #
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
    :path_params,
    :query_params,
    :headers,
    :body,
    :resource
  )

  Resource  = Struct.new(
    :operation_id,
    :path,
    :expected_request
  )
end