# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    main.rb                                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:13 by craimond          #+#    #+#              #
#    Updated: 2024/10/20 10:31:33 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'lib/server'

begin

Server.new.run

#TODO parse variables settings from .conf file into global vars each time server receives specific signal (e.g. SIGHUP)
#if you change some settings such as bind_address or port the server should restart

rescue => e
    STDERR.puts "Fatal Error: #{e.message}"
