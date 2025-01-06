# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_validation_middleware.rb                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/06 15:21:56 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 16:04:50 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../../shared/exceptions'

class RequestValidationMiddleware

  def initialize(app)
    @app = app
  end

  def call(env)
    raise Unauthorized.new("Unauthorized") unless env["HTTP_AUTHORIZATION"]
    raise NotAcceptable.new("Not acceptable") unless env["HTTP_ACCEPT"]&.include?('text/event-stream')
  end

end