# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    auth_user_service_handler.rb                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/11/28 06:56:40 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require_relative '../config_handler'
require_relative '../grpc_server'

class AuthUserServiceHandler < AuthUser::Service
  include ServiceHandlerMiddleware

  def initialize
    @config = ConfigHandler.instance.config
  end

  def ping(_request, _call)
    Google::Protobuf::Empty.new
  end

  def check_domain(request, _call)
    
  end

  def hash_password(request, _call)
    
  end

  def generate_tfa_secret(_request, _call)
    
  end

  def check_tfa_code(request, _call)
    
  end

  def generate_jwt(request, _call)
    
  end

end