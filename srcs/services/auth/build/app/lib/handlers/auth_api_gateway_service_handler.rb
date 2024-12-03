# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_api_gateway_service_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 22:04:52 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require 'bcrypt'
require 'rotp'
require 'resolv'
require_relative '../config_handler'
require_relative '../grpc_server'

class AuthUserServiceHandler < AuthUser::Service

  def initialize
    @config = ConfigHandler.instance.config
    @private_key = OpenSSL::PKey::RSA.new(@config[:jwt][:private_key])
  end

  def ping(_request, _call)
    Empty.new
  end

  

  private

end