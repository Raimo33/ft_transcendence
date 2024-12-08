# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/13 18:07:59 by craimond          #+#    #+#              #
#    Updated: 2024/12/08 22:09:06 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19 as official

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache nodejs npm

COPY ./site /var/www/html

WORKDIR /var/www/html

RUN npm install bootstrap

VOLUME ["var/www/html"]