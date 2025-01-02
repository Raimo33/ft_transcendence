# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    notification_match_service_handler.rb              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2025/01/02 13:31:24 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require 'base64'
require_relative '../config_handler'
require_relative '../protos/notification_user_services_pb'

class NotificationUserServiceHandler < NotificationUser::Service
  
  def initialize
    @config = ConfigHandler.instance.config
  end

  def ping(request, call)
    Empty.new
  end

  #TODO implement

  private

  def check_required_fields(*fields)
    raise GRPC::InvalidArgument.new("Missing required fields") unless fields.all?(&method(:provided?))
  end

  def provided?(field)
    field.respond_to?(:empty?) ? !field.empty? : !field.nil?
  end

end