# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Logger.rb                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/01 15:30:08 by craimond          #+#    #+#              #
#    Updated: 2024/11/02 18:31:50 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'logger'

module Logger

  LOG_LEVELS_MAP = {
    'DEBUG' => Logger::DEBUG,
    'INFO' => Logger::INFO,
    'WARN' => Logger::WARN,
    'ERROR' => Logger::ERROR
  }.freeze

  def self.create(log_level, log_file)
    logger = Logger.new(log_file)
    logger.level = LOG_LEVELS_MAP[log_level]
    logger.formatter = proc do |severity, datetime, progname, msg|
      "#{time.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
    end

    logger
  end

  def self.logger
    @logger ||= create
  end

end