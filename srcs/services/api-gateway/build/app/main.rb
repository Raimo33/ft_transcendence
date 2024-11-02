# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    main.rb                                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/23 20:40:44 by craimond          #+#    #+#              #
#    Updated: 2024/11/02 15:23:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'lib/ApiGateway'

begin
  config_file = ARGV[0] || '/etc/api-gateway/conf.d/default.conf'
  api_gateway = APIGateway.new(config_file)
  api_gateway.start_master
end