# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    config.ru                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:11:18 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 15:26:04 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../srcs/handlers/request_handler'
require_relative '../srcs/middleware/server/authentication_middleware'
require_relative '../srcs/middleware/server/logger_middleware'
require_relative '../srcs/middleware/server/exceptions_middleware'
require 'openapi_first'

openapi_spec = OpenapiFirst.load('main_oas.yaml')

use ExceptionsMiddleware
use OpenapiFirst::Middlewares::RequestValidation, spec: openapi_spec, raise_error: true
use AuthMiddleware
use LoggerMiddleware
use Rack::ContentType, 'application/json'
use Rack::ContentLength
use Rack::Deflater

app = RequestHandler.new
run app