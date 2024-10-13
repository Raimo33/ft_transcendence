# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/13 18:07:59 by craimond          #+#    #+#              #
#    Updated: 2024/10/13 18:19:09 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache nginx

COPY ./conf/default.conf /etc/nginx/http.d/default.conf

RUN adduser -SDH nginx
RUN chown -R nginx:nginx /var/lib/nginx /etc/nginx/ /var/log/nginx

WORKDIR /etc/nginx/http.d
USER nginx
EXPOSE 80 443
VOLUME []

CMD ["tail", "-f", "/dev/null"]
# CMD ["nginx", "-g", "daemon off;"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["curl", "-fks", "nginx.edgenet:443"]

