# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_context_middleware.rb                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:19:12 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../request_context'

class RequestContextMidleware

  def initialize(app)
    @app = app
  end

  def call(request)
    RequestContext.request_id = SecureRandom.uuid
    @app.call(request)
  end

end
