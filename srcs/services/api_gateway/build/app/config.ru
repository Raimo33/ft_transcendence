# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    config.ru                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:11:18 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:01:10 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'lib/server'
require_relative 'lib/middleware/auth_middleware'
require_relative 'lib/middleware/logger_middleware'
require_relative 'lib/middleware/exception_middleware'
require 'openapi_first'

openapi_spec = OpenapiFirst.load('config/openapi.yaml')

use OpenapiFirst::Middlewares::RequestValidation, spec: openapi_spec, raise_error: true
use Middleware::LoggerMiddleware
use Middleware::AuthMiddleware
use Middleware::ExceptionMiddleware
use Rack::ContentType, 'application/json'
use Rack::ContentLength
use Rack::Deflater
use OpenapiFirst::Middlewares::ResponseValidation, spec: openapi_spec, raise_error: true if ENV['RACK_ENV'] == 'development'


app = Server.new
run app