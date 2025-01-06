# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    config.ru                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:11:18 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 15:10:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../srcs/server'
require_relative '../srcs/middleware/server/authentication_middleware'
require_relative '../srcs/middleware/server/logger_middleware'
require_relative '../srcs/middleware/server/exceptions_middleware'

#TODO parsing della richiesta, capire cosa fare tramite RACK
use LoggerMiddleware
use AuthMiddleware
use ExceptionsMiddleware
use Rack::ContentType, 'text/event-stream'
use Rack::ContentLength
use Rack::Deflater

app = Server.new
run app