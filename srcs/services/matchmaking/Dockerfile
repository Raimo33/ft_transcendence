# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2024/12/26 21:38:00 by craimond         ###   ########.fr        #
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
COPY --from=protos \
  matchmaking_match.proto \
  match_matchmaking.proto \
  /app/protos/

RUN adduser -DHS matchmaking
RUN chown -R matchmaking:matchmaking /app

WORKDIR /app/protos
RUN grpc_tools_ruby_protoc -I ./ --ruby_out=./ --grpc_out=./ \
  matchmaking_match.proto \
  match_matchmaking.proto

WORKDIR /app
USER matchmaking
EXPOSE 3000
VOLUME ["/etc/ssl/public"]

ENTRYPOINT ["falcon", "serve", \
            "--bind", "http://0.0.0.0:3000", \
            "--config", "config.ru", \
            "--environment", "production", \
            "--protocol", "HTTP1", \
            "--reuse-port", \
            "--quiet"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["curl", "-fks", "http://localhost:3000/ping"]