# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    custom_logger.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/28 04:20:43 by craimond          #+#    #+#              #
#    Updated: 2024/11/28 04:24:00 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'logger'
require 'singleton'
require_relative 'config_handler'

class CustomLogger
  include Singleton
  attr_reader :logger

  def initialize
    @config = ConfigHandler.instance.config

    log_file  = @config.dig('logging', 'file')  || $stdout
    log_level = @config.dig('logging', 'level') || 'INFO'

    @logger = Logger.new(log_file)
    @logger.level = Logger.const_get(log_level.upcase)
    @logger.formatter = proc do |severity, datetime, _, msg|
      tag = @config.dig('logging', 'tag')
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S.%L')}] #{severity} [#{tag}]: #{msg}\n"
    end
  end

end

