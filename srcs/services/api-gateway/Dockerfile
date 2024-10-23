# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2024/10/23 22:00:15 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19 as official

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache ruby ruby-json ruby-dev build-base libffi-dev

RUN mkdir -p /etc/api-gateway/conf.d

COPY ./app                   /app
COPY ./build/default.conf    /etc/api-gateway/conf.d/
#TODO: aggiungere il comando tipo nginx -t per verificare la correttezza del file di configurazione
COPY ./build/.sh             /usr/local/bin/

RUN adduser -DHS api-gateway
RUN chown -R api-gateway:api-gateway /app
RUN chmod +x /usr/local/bin/

WORKDIR /etc/api-gateway/conf.d/
USER api-gateway
EXPOSE 3000

ENTRYPOINT ["ruby", "main.rb"]
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["curl", "-f", "http://localhost:3000/api/v1/ping"]

FROM official as pongfumasters

RUN mkdir -p /shared

WORKDIR /shared
VOLUME ["/shared"]

CMD ["-c", "/shared/conf/api-gateway.conf"]