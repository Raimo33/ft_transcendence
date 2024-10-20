# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    main.rb                                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:13 by craimond          #+#    #+#              #
#    Updated: 2024/10/20 08:37:46 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'lib/server'

begin

Server.new.run

#TODO parse global variables settings from .conf file each time server receives specific signal (e.g. SIGHUP)
#if you change some settings such as bind_address or port the server should restart

rescue => e
    STDERR.puts "Fatal Error: #{e.message}"
