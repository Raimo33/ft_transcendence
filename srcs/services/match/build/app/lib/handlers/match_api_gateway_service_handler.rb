# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match_api_gateway_service_handler.rb               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:38:09 by craimond          #+#    #+#              #
#    Updated: 2024/12/09 21:58:17 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'async'
require_relative '../config_handler'
require_relative '../grpc_client'
require_relative '../db_client'

class MatchAPIGatewayServiceHandler < MatchAPIGateway::Service
  include EmailValidator

  def initialize
    @config       = ConfigHandler.instance.config
    @grpc_client  = GrpcClient.instance
    @db_client    = DBClient.instance

    @prepared_statements = {
      get_user_matches: <<~SQL
        #TODO trovare un modo per evitare il sorting ogni volta (limit e offset servono a quello)
      SQL
    }

    prepare_statements
  end

  def ping(request, call)
    Empty.new
  end

  def get_user_matches(request, call)
    check_required_fields(request.user_id)

    limit  = request.limit || 10
    offset = request.offset || 0


  private

  def check_required_fields(*fields)
    raise GRPC::InvalidArgument.new("Missing required fields") unless fields.all?(&method(:provided?))
  end

  def provided?(field)
    field.respond_to?(:empty?) ? !field.empty? : !field.nil?
  end

end