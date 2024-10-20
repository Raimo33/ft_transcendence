# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2024/10/20 12:04:07 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache ruby ruby-json ruby-dev build-base libffi-dev

COPY ./app                    /app
COPY ./tools/inject_conf.sh   /usr/local/bin/

RUN mkdir -p /etc/api-gateway /var/run/api-gateway

RUN adduser -DHS api-gateway
RUN chown -R api-gateway:api-gateway /app /etc/api-gateway /var/run/api-gateway
RUN chmod +x /usr/local/bin/inject_conf.sh

WORKDIR /app 
USER api-gateway
EXPOSE 3000
VOLUME ["/etc/api-gateway"]

ENTRYPOINT ["load-conf", "default.template.conf"]
CMD ["ruby", "main.rb"]

# HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD 