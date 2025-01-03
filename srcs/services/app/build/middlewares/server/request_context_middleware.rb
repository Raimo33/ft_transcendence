# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_context_middleware.rb                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 11:28:55 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../request_context'

class RequestContextMiddleware

  def initialize(app)
    @app = app
  end

  def call(request)
    RequestContext.request_id = SecureRandom.uuid
    @app.call(request)
  end

end
