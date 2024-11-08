# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2024/11/08 21:31:53 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19 as official

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache ruby protobuf

RUN mkdir -p /etc/api_gateway/conf.d
RUN touch /var/log/api_gateway.log

COPY ./build/app/            /app
COPY ./build/default.conf    /etc/api_gateway/conf.d/

RUN adduser -DHS api_gateway
RUN chown -R api_gateway:api_gateway /app /etc/api_gateway /var/log/api_gateway.log
RUN chmod -R +x /usr/local/bin/

WORKDIR /app
RUN gem install bundler
RUN bundle install
WORKDIR /app/proto
RUN protoc --ruby_out=./ user.proto match.proto tournament.proto

WORKDIR /etc/api_gateway/conf.d/
EXPOSE 3000

ENTRYPOINT ["./main.rb"]
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["curl", "-f", "http://localhost:3000/api/v1/ping"]

FROM official as pongfumasters

RUN mkdir -p /shared

USER api_gateway
WORKDIR /shared
VOLUME ["/shared"]

CMD ["-c", "/shared/conf/api_gateway.conf"]