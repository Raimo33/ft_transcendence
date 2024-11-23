# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 14:27:54 by craimond          #+#    #+#              #
#    Updated: 2024/11/23 17:40:57 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'falcon'
require 'openapi_first'
require 'json'
require_relative 'ConfigHandler'

class Server
  OPENAPI_PATH = '../config/openapi.yaml'

  def initialize
    @definition = OpenapiFirst.load(OPENAPI_PATH)
  end

  def call(env)
    request = Falcon::Request.new(env)
    validated_request = env[OpenapiFirst::REQUEST]

    handler = find_handler(validated_request.operation['operationId'])
    response = handler.call(validated_request.params)

    response
  end

  private

  def find_handler(operation_id)
    handler_class = "#{operation_id.capitalize}Handler"
    Object.const_get(handler_class).new
  end

  def error_response(status, message)
    [
      status,
      { 'Content-Type' => 'application/json' },
      [{ error: message }.to_json]
    ]
  end
end