# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    request_handler.rb                                 :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 14:27:54 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 14:31:48 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'json'
require 'async'
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
    
    #TODO parsing? collgearsi a connection_handler_module

  rescue NoMethodError
    raise NotFound.new("Operation not found")
  end

  private

  def subscribe

  def check_required_fields(*fields)
    fields.each do |field|
      raise BadRequest.new("Missing required field: #{field}") if field.nil? || field.empty?
    end
  end

end