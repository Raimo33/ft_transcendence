# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    config.ru                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:11:18 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 16:42:47 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'lib/server'
require_relative 'lib/middleware/server/auth_middleware'
require_relative 'lib/middleware/server/logger_middleware'
require_relative 'lib/middleware/server/exception_middleware'
require 'openapi_first'

openapi_spec = OpenapiFirst.load('config/openapi.yaml')

use RequestIdMiddleware
use OpenapiFirst::Middlewares::RequestValidation, spec: openapi_spec, raise_error: true
use LoggerMiddleware
use AuthMiddleware
use ExceptionMiddleware
use Rack::ContentType, 'application/json'
use Rack::ContentLength
use Rack::Deflater
use OpenapiFirst::Middlewares::ResponseValidation, spec: openapi_spec, raise_error: true if ENV['RACK_ENV'] == 'development'


app = Server.new
run app