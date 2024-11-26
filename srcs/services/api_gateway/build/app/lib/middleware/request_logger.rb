# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_logger.rb                                  :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 17:28:27 by craimond          #+#    #+#              #
#    Updated: 2024/11/26 19:58:06 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'logger'
require '../config_handler'

class RequestLogger
  def initialize(app)
    @app    = app
    @logger = Logger.new($stdout)
    @config = ConfigHandler.instance.config
    @logger.formatter = proc do |severity, datetime, _, msg|
      tag = @config.dig('logging', 'tag')
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S.%L')}] #{severity} [#{tag}]: #{msg}\n"
    end
  end

  def call(env)
    request = Rack::Request.new(env)

    @logger.info("Started #{request.request_method} #{request.path}")
    status, headers, response = @app.call(env)
    @logger.info("Completed #{request.request_method} #{request.path}")

    [status, headers, response]
  end
end

