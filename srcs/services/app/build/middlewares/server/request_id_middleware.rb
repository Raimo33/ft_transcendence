# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_id_middleware.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 17:17:26 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class RequestContextMiddleware

  def initialize(app)
    @app = app
  end

  def call(env)
    env[:request_id] = SecureRandom.uuid
    @app.call(env)
  end

end
