# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    UserServiceHandler.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/08 20:01:35 by craimond          #+#    #+#              #
#    Updated: 2024/11/08 20:07:18 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative './modules/Logger'
require_relative './modules/ConfigLoader'
require_relative '../proto/user_service_pb'

class UserServiceHandler < UserService::Service

  #TODO: Implement the service methods, include the grpcClient

end