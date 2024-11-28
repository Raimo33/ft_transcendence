# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_api_gateway_service_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/28 06:56:53 by craimond          #+#    #+#              #
#    Updated: 2024/11/28 07:00:32 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require_relative '../config_handler'
require_relative '../grpc_server'

class AuthAPIGatewayServiceHandler < AuthAPIGateway::Service
  include ServiceHandlerMiddleware

  def initialize
    @config = ConfigHandler.instance.config
  end

  def ping(_request, _call)
    Google::Protobuf::Empty.new
  end

  def get_user_public_keys(_request, _call)
    
  end

end