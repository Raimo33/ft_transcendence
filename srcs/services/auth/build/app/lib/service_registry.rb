# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    service_registry.rb                                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/25 17:38:56 by craimond          #+#    #+#              #
#    Updated: 2024/11/26 17:10:45 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'singleton'

class ServiceRegistry
  include Singleton
  attr_reader :services

  def initialize
    @services = {}
  end

  def register(service_class, handler_class)
    handler_instance = handler_class.new
    wrapped_handler = ServerMiddleware.wrap(handler_instance).new
    @services[service_class] = wrapped_handler
  end

end