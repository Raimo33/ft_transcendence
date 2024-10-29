# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    structs.rb                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/28 19:55:38 by craimond          #+#    #+#              #
#    Updated: 2024/10/29 14:36:38 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

ExpectedRequest = Struct.new(:allowed_path_params, :allowed_query_params, :allowed_headers, :body_schema)
ExpectedResponse = Struct.new(:status_code, :allowed_headers, :body_schema)

Response = Struct.new(:status_code, :headers, :body)
Request = Struct.new(:http_method, :path_params, :query_params, :headers, :body)
Resource = Struct.new(:http_method, :expected_auth, :expected_request, :expected_responses, :operation_id)