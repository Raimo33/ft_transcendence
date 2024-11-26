# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_logger.rb                                  :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 17:29:02 by craimond          #+#    #+#              #
#    Updated: 2024/11/26 20:00:02 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'logger'

class RequestLogger
  def initialize(app)
    @app = app
    @logger = Logger.new($stdout)
    @config = ConfigHandler.instance.config
    @logger.formatter = proc do |severity, datetime, _, msg|
      tag = @config.dig('logging', 'tag')
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S.%L')}] #{severity} [#{tag}]: #{msg}\n"
    end
  end

  def call(request, call)
    @logger.info("Started #{call.method_name} - Metadata: #{call.metadata.to_h}")
    response = @app.call(request, call)
    @logger.info("Completed #{call.method_name} - Metadata: #{call.metadata.to_h}")
    
    response
  end

end
