# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 14:27:54 by craimond          #+#    #+#              #
#    Updated: 2024/12/02 20:32:49 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'falcon'
require 'openapi_first'
require 'json'
require_relative 'ConfigHandler'

class Server

  def call(env)
    request  = env[OpenapiFirst::REQUEST]
    handler  = find_handler(request.operation['operationId'])

    handler.call(request, env['requester_user_id'])
  end

  private

  def find_handler(operation_id)
    handler_class = "#{operation_id.capitalize}Handler"
    Object.const_get(handler_class).new
  end

end