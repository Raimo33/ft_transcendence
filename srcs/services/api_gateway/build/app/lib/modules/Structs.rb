# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Structs.rb                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/28 19:55:38 by craimond          #+#    #+#              #
#    Updated: 2024/11/18 17:36:13 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

module Structs
  ExpectedRequest = Struct.new(
    :allowed_path_params,
    :allowed_query_params,
    :allowed_headers,
    :body_schema,
    :keyword_init: true
  )

  Response  = Struct.new(
    :status_code,
    :headers,
    :body,
    :keyword_init: true
  )

  Request   = Struct.new(
    :http_method,
    :path_params,
    :query_params,
    :headers,
    :body,
    :resource,
    :keyword_init: true
  )

  Resource  = Struct.new(
    :path_template,
    :http_method,
    :expected_auth_level,
    :expected_request,
    :expected_responses,
    :operation_id,
    :keyword_init: true
  )
end