# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    notification_app_service_handler.rb                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/05 17:29:28 by craimond          #+#    #+#              #
#    Updated: 2025/01/07 19:50:32 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../config_handler'
require_relative '../connection_manager'
require_relative '../protos/notification_app_services_pb'

class NotificationAppServiceHandler < NotificationApp::Service
  def initialize
    @config = ConfigHandler.instance.config
    @connection_manager = ConnectionManager.instance
  end

  def notify_friend_request(request, call)
    sender_id, receiver_id = request.sender_id, request.receiver_id
    check_required_fields(sender_id, receiver_id)

    @connection_manager.notify(
      #TODO: Implement this
    )

    Empty.new
  end

  def notify_friend_request_accepted(request, call)

  def notify_match_found(request, call)

  private

  def check_required_fields(*fields)
    fields.each do |field|
      raise BadRequest.new("Missing required field: #{field}") if field.nil? || field.empty?
    end
  end

end