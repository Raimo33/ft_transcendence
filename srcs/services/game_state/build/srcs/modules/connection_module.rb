# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    connection_module.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/04 17:07:24 by craimond          #+#    #+#              #
#    Updated: 2025/01/04 17:13:58 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'singleton'
require_relative 'auth_module'
require_relative '../shared/config_handler'
require_relative '../shared/custom_logger'
require_relative '../shared/exceptions'

class ConnectionModule
  include Singleton

  #TODO connection module, message handler module etc.

end