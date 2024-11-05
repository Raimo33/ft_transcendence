# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2024/11/05 15:31:40 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19 as official

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache ruby protobuf

RUN mkdir -p /etc/api-gateway/conf.d
RUN touch /var/log/api-gateway.log

COPY ./build/app/            /app
COPY ./build/default.conf    /etc/api-gateway/conf.d/

RUN adduser -DHS api-gateway
RUN chown -R api-gateway:api-gateway /app /etc/api-gateway /var/log/api-gateway.log
RUN chmod -R +x /usr/local/bin/

WORKDIR /app
RUN gem install bundler
RUN bundle install
WORKDIR /app/proto
RUN protoc --ruby_out=./ user.proto match.proto tournament.proto

WORKDIR /etc/api-gateway/conf.d/
EXPOSE 3000

ENTRYPOINT ["./main.rb"]
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["curl", "-f", "http://localhost:3000/api/v1/ping"]

FROM official as pongfumasters

RUN mkdir -p /shared

USER api-gateway
WORKDIR /shared
VOLUME ["/shared"]

CMD ["-c", "/shared/conf/api-gateway.conf"]