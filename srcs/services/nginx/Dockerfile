# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/09/28 19:08:08 by craimond          #+#    #+#              #
#    Updated: 2024/10/01 10:48:03 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/06/17 15:52:59 by craimond          #+#    #+#              #
#    Updated: 2024/09/15 16:06:36 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

ARG USER_ID GROUP_ID1

RUN apk add --no-cache nginx curl

COPY ./conf/	/etc/nginx/http.d/

#TODO controllare se utile
RUN mkdir -p /run/nginx

RUN adduser -u $USER_ID -SDH nginx-user
RUN chown -R nginx-user /var/lib/nginx /run/nginx /etc/nginx/http.d /var/log/nginx

WORKDIR /etc/nginx/http.d
USER nginx-user
EXPOSE 80 443
VOLUME ["/var/www/html", "/etc/ssl/certs"]

ENTRYPOINT ["nginx", "-g", "daemon off;"]

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD ["curl", "-fks", "https://nginx.backend:443"]