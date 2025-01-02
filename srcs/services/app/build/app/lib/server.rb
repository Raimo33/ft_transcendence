# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 14:27:54 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:06:47 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'falcon'
require 'openapi_first'
require 'json'
require_relative 'ConfigHandler'

class Server

  def initialize
    @handlers = {}
  end

  def call(env)
    parsed_request = env[OpenapiFirst::REQUEST]
    handler = find_handler(parsed_request.operation['operationId'], env)

    handler.call(parsed_request)
  end

  private

  def find_handler(operation_id)
    handler_class = "#{operation_id.capitalize}Handler"
    @handlers[handler_class] ||= Object.const_get(handler_class).new
  end

end