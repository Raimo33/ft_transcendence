# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    middleware_registry.rb                             :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:48:51 by craimond          #+#    #+#              #
#    Updated: 2024/11/26 18:48:51 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'singleton'

class MiddlewareRegistry
  include Singleton
  attr_reader :middlewares

  def initialize
    @middlewares = []
  end

  def use(middleware_class)
    @middlewares << middleware_class
  end
end