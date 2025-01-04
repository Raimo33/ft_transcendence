# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/13 18:07:59 by craimond          #+#    #+#              #
#    Updated: 2025/01/04 00:45:35 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache nginx nginx-mod-http-brotli nginx-mod-http-v3 openssl-quictls 

COPY ./build/nginx.conf               /etc/nginx/nginx.conf
COPY ./build/http.d/                  /etc/nginx/http.d/
COPY --from=certs nginx.crt           /etc/ssl/public/nginx.crt
COPY --from=certs nginx_ca-bundle.crt /etc/ssl/public/nginx_ca-bundle.crt

WORKDIR /var/www/html
VOLUME ["var/www/html", "/etc/ssl/private"]
USER nginx
EXPOSE 80 443/tcp 443/udp

ENTRYPOINT ["nginx", "-g", "daemon off;"]
CMD ["-c", "/etc/nginx/nginx.conf"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["curl", "-fks", "--http3", "https://nginx.edge:443"]