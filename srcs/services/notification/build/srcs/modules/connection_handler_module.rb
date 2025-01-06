# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    connection_handler_module.rb                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/06 13:45:12 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 16:08:45 by craimond         ###   ########.fr        #
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

    notify(user_id, 'connected', {})
  end

  def remove_connection(user_id, stream)
    notify(user_id, 'disconnected', {})

    @connections[user_id]&.delete(stream)
    @connections.delete(user_id) if @connections[user_id]&.empty?
  end

  def notify(user_id, event_type, data)
    return unless @connections[user_id]

    message = format_sse(event_type, data)
    @connections[user_id].each do |stream|
      stream.write(message)
      stream.flush
    end
  end

  private

  def format_sse(event, data)
    "event: #{event}\ndata: #{JSON.generate(data)}\n\n"
  end

end