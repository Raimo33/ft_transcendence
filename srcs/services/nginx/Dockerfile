# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/13 18:07:59 by craimond          #+#    #+#              #
#    Updated: 2024/12/01 13:56:40 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache nginx

COPY ./build/nginx.conf    /etc/nginx/nginx.conf
COPY ./build/headers.conf  /etc/nginx/http.d/headers.conf

WORKDIR /var/www/html
VOLUME ["var/www/html", "/etc/ssl/certs"]
USER nginx
EXPOSE 80 443

ENTRYPOINT ["nginx", "-g", "daemon off;"]
CMD ["-c", "/etc/nginx/nginx.conf"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["curl", "-fks", "--http2", "--tlsv1.3", "https://nginx.edge:443"]