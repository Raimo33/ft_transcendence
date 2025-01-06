# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    connection_handler_module.rb                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/06 13:45:12 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 14:12:43 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'singleton'

class ConnectionHandlerModule
  include Singleton
  
  def initialize
    @connections = {}
  end

  def add_connection(user_id, stream)
    @connections[user_id] ||= []
    @connections[user_id] << stream
  end

  def remove_connection(user_id, stream)
    @connections[user_id]&.delete(stream)
    @connections.delete(user_id) if @connections[user_id]&.empty?
  end

  def notify(user_id, event_type, data)
    return unless @connections[user_id]

    message = format_sse(event_type, data)
    @connections[user_id].each { |stream| stream.write(message) }
  end

  private

  def format_sse(event, data)
    "event: #{event}\ndata: #{JSON.generate(data)}\n\n"
  end

end