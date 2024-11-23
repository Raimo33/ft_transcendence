# config.ru
require_relative 'lib/server'
require_relative 'lib/middleware/authorization'
require_relative 'lib/middleware/request_logger'
require_relative 'lib/middleware/exception_handler'

require 'falcon'
require 'openapi_first'

openapi_spec = OpenapiFirst.load('config/openapi.yaml')

use Rack::CommonLogger, Logger.new($stdout)
use RequestLogger
use Rack::ContentType, 'application/json'
use Rack::ContentLength
use Rack::Deflater
use OpenapiFirst::Middlewares::RequestValidation, spec: openapi_spec, raise_error: true
use Authorization
use ExceptionHandler
use OpenapiFirst::Middlewares::ResponseValidation, spec: openapi_spec, raise_error: true if ENV['RACK_ENV'] == 'development'

app = Server.new
run app