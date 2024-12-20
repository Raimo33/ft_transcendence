# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    config_handler.rb                                  :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 16:21:31 by craimond          #+#    #+#              #
#    Updated: 2024/11/28 06:43:27 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'yaml'
require 'singleton'

class ConfigHandler
  include Singleton

  attr_reader :config

  CONFIG_PATH  = '../config/config.yaml'

  def initialize
    @config = YAML.load_file(CONFIG_PATH)
  end
end