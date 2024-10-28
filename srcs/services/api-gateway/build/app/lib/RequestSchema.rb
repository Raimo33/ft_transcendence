# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Request.rb                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/27 16:54:20 by craimond          #+#    #+#              #
#    Updated: 2024/10/27 17:58:20 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class Request
  attr_accessor :allowed_path_params,     # Array of parameter names from path (e.g., ["id"])
                :allowed_query_params,    # Hash of query parameters
                :allowed_headers,         # Array of allowed headers
                :body_type,               # Hash of request body type

  def initialize(allowed_path_params, allowed_query_params, allowed_headers, body_type)
    @allowed_path_params   = allowed_path_params
    @allowed_query_params  = allowed_query_params
    @allowed_headers       = allowed_headers
    @body_type             = request_body_type
  end
end