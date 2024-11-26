# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    service_registry.rb                                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/25 17:38:56 by craimond          #+#    #+#              #
#    Updated: 2024/11/25 17:39:00 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'singleton'

class ServiceRegistry
  include Singleton

  def initialize
    @services = {}
  end

  def register(service_class, handler_class)
    @services[service_class] = handler_class.new
  end

  def registered_services
    @services
  end
end