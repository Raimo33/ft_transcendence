# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/13 18:07:59 by craimond          #+#    #+#              #
#    Updated: 2024/10/22 17:30:30 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache nginx

COPY --chmod=755 ./tools/ /usr/local/bin/

WORKDIR /etc/nginx/http.d
VOLUME ["/etc/nginx/http.d"]
USER nginx
EXPOSE 80 443

ENTRYPOINT ["parse-conf", "default.conf.template"]
CMD ["nginx", "-g", "daemon off;"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["curl", "-fks", "nginx.edgenet:443"]