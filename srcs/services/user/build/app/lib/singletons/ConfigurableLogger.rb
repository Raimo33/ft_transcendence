# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    ConfigurableLogger.rb                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/01 15:30:08 by craimond          #+#    #+#              #
#    Updated: 2024/11/18 18:27:48 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "logger"
require "singleton"

class ConfigurableLogger
  include Singleton

  attr_reader :logger

  LOG_LEVELS_MAP = {
    "debug"     => Logger::DEBUG,
    "info"      => Logger::INFO,
    "warn"      => Logger::WARN,
    "error"     => Logger::ERROR,
    "fatal"     => Logger::FATAL,
    "unknown"   => Logger::UNKNOWN
  }.freeze

  def initialize(log_level: = "info", log_output: = STDOUT, tag: = nil)
    @tag = tag.uppercase
    @logger = Logger.new(log_output)
    @logger.level = LOG_LEVELS_MAP[log_level.uppercase] || Logger::INFO
  end

  def add(severity, message: = nil, progname: = nil, &block)
    message = "[#{@tag}] #{message}"
    super(severity, message, progname, &block)
  end
end