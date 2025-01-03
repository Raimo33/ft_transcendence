# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    config.ru                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:11:18 by craimond          #+#    #+#              #
#    Updated: 2025/01/03 11:32:17 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative '../lib/server'
require_relative '../lib/middleware/server/authentication_middleware'
require_relative '../lib/middleware/server/logger_middleware'
require_relative '../lib/middleware/server/exceptions_middleware'
require_relative '../lib/middleware/server/request_context_middleware'
require 'openapi_first'

openapi_spec = OpenapiFirst.load('main_oas.yaml')

use RequestContextMidleware
use OpenapiFirst::Middlewares::RequestValidation, spec: openapi_spec, raise_error: true
use LoggerMiddleware
use AuthMiddleware
use ExceptionsMiddleware
use Rack::ContentType, 'application/json'
use Rack::ContentLength
use Rack::Deflater

app = Server.new
run app