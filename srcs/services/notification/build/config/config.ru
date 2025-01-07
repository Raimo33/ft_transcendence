# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    config.ru                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:11:18 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 15:30:05 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../srcs/server'
require_relative '../srcs/middleware/server/authentication_middleware'
require_relative '../srcs/middleware/server/logger_middleware'
require_relative '../srcs/middleware/server/exceptions_middleware'
require_relative '../srcs/middleware/server/request_validation_middleware'

use ExceptionsMiddleware
use RequestValidationMiddleware
use LoggerMiddleware
use AuthMiddleware
use Rack::ContentType, 'text/event-stream'
use Rack::ContentLength
use Rack::Deflater

app = Server.new
run app