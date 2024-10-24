# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/13 18:07:59 by craimond          #+#    #+#              #
#    Updated: 2024/10/23 22:06:31 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19 as official

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache nginx

WORKDIR /etc/nginx/http.d
VOLUME ["/etc/nginx/http.d"]
USER nginx
EXPOSE 80 443

ENTRYPOINT ["nginx", "-g", "daemon off;"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["curl", "-fks", "nginx.edgenet:443"]

FROM official as pongfumasters

RUN mkdir -p /shared

WORKDIR /shared
VOLUME ["/shared"]

CMD ["-c", "/shared/conf/nginx.conf"]