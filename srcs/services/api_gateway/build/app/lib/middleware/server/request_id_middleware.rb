# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_id_middleware.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/03 16:43:11 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 16:43:23 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class RequestIdMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    env['HTTP_X_REQUEST_ID'] = SecureRandom.uuid
    @app.call(env)
  end
end