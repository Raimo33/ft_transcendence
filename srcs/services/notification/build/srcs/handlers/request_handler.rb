# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_handler.rb                                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 14:27:54 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 16:12:51 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'rack/sse'
require 'json'
require 'async/http/body/writable'
require 'async/http/protocol'
require_relative 'shared/config_handler'
require_relative 'shared/exceptions'
require_relative 'shared/request_context'
require_relative 'modules/connection_handler_module'

class RequestHandler

  def initialize
    @config = ConfigHandler.instance.config

    @connection_handler_module = ConnectionHandlerModule.instance
  end

  def call(env)
    path = env["PATH_INFO"]
    
    user_id = path.split('/').last
    raise Forbidden.new("Access denied") unless user_id == RequestContext.requester_user_id
    
    case env["REQUEST_METHOD"]
    when "GET"
      subscribe(user_id, env)
    when "DELETE"
      unsubscribe(user_id, env)
    else
      raise MethodNotAllowed.new("Method not allowed")
    end
  end

  private

  def subscribe(user_id, env)
    headers = {
      "Content-Type"  => "text/event-stream",
      "Cache-Control" => "no-cache",
      "Connection"    => "keep-alive"
    }
    stream = Async::HTTP::Body::Writable.new
    response = Async::HTTP::Response.new(200, headers, stream)
    @connection_handler_module.add_connection(user_id, stream)

    response
  end

  def unsubscribe
    @connection_handler_module.remove_connection(user_id, stream)
  end

end