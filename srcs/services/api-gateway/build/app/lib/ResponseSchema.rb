# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Response.rb                                        :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/27 16:55:21 by craimond          #+#    #+#              #
#    Updated: 2024/10/27 16:56:26 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class Response
  attr_accessor :status_code,    # (e.g., 200)
                :headers,        # Hash of headers
                :body_type       # Hash of response body type

  def initialize(status_code, headers, body_type)
    @status_code = status_code
    @headers = headers
    @body_type = body_type
  end
end