# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    config.ru                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/24 20:11:18 by craimond          #+#    #+#              #
#    Updated: 2024/11/24 20:31:46 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'lib/server'
require_relative 'lib/middleware/authorization'
require_relative 'lib/middleware/request_logger'
require_relative 'lib/middleware/exception_handler'
require 'openapi_first'

openapi_spec = OpenapiFirst.load('config/openapi.yaml')

use Rack::CommonLogger, Logger.new($stdout)
use RequestLogger
use OpenapiFirst::Middlewares::RequestValidation, spec: openapi_spec, raise_error: true
use Authorization
use ExceptionHandler
use Rack::ContentType, 'application/json'
use Rack::ContentLength
use Rack::Deflater
use OpenapiFirst::Middlewares::ResponseValidation, spec: openapi_spec, raise_error: true if ENV['RACK_ENV'] == 'development'

app = Server.new
run app