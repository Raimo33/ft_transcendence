# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2024/11/23 15:07:40 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache ruby protobuf

RUN adduser -DHS api_gateway
RUN chown -R api_gateway:api_gateway /app
RUN chmod -R +x /usr/local/bin/

COPY --chown=api_gateway:api_gateway ./build/app/ /app

WORKDIR /app
RUN gem install bundler
RUN bundle install
WORKDIR /app/proto
RUN protoc --ruby_out=./ user.proto match.proto tournament.proto

USER api_gateway
WORKDIR /app
EXPOSE 3000

ENTRYPOINT ["falcon", "serve", \
            "--bind", "http://0.0.0.0:3000", \
            "--config", "config.ru", \
            "--timeout", "30", \
            "--backlog", "1024", \
            "--environment", "production", \
            "--protocol", "HTTP2", \
            "--reuse-port", \
            "--quiet"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["curl", "-fks", "http://localhost:3000/ping"]