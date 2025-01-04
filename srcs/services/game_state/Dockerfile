# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2025/01/04 00:47:03 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache ruby protobuf

COPY ./build/Gemfile ./build/Gemfile.lock /app/

WORKDIR /app
RUN gem install bundler
RUN bundle install

COPY ./build/srcs/                      /app/srcs/
COPY --from=protos game_state_app.proto /app/srcs/protos/
COPY --from=certs jwtRS256.key.pub      /etc/ssl/public/jwtRS256.key.pub

RUN adduser -DHS game_state
RUN chown -R game_state:game_state /app

WORKDIR /app/srcs
RUN grpc_tools_ruby_protoc -I ./protos --ruby_out=./protos --grpc_out=./protos game_state_app.proto

USER game_state
EXPOSE 8080 50051
# VOLUME []

ENTRYPOINT ["ruby", "main.rb"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD [#TODO websocket ping]