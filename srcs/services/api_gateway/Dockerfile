# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2024/12/09 16:46:47 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache ruby protobuf

COPY ./build/Gemfile ./build/Gemfile.lock /app/

WORKDIR /app
RUN gem install bundler
RUN bundle install

COPY ./build/app/   /app/
COPY --from=protos match_api_gateway.proto \
                   tournament_api_gateway.proto \
                   user_api_gateway.proto \
                   /app/protos/

RUN adduser -DHS api_gateway
RUN chown -R api_gateway:api_gateway /app

RUN protoc --ruby_out=./ /app/protos/match_api_gateway.proto \
                         /app/protos/tournament_api_gateway.proto \
                         /app/protos/user_api_gateway.proto

USER api_gateway
EXPOSE 3000
VOLUME ["/etc/ssl/public"]

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