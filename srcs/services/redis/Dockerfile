# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2024/12/09 17:45:22 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache redis

COPY ./build/redis.conf /etc/redis.conf
COPY ./build/redis.acl  /etc/redis.acl

USER redis
EXPOSE 6379
VOLUME []

ENTRYPOINT ["redis-server", "/etc/redis.conf"]
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["redis-cli", "ping"]