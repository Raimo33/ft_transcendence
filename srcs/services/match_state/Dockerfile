# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2025/01/05 16:08:50 by craimond         ###   ########.fr        #
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
COPY --from=protos match_state_app.proto /app/srcs/protos/
COPY --from=certs jwtRS256.key.pub      /etc/ssl/public/jwtRS256.key.pub

RUN adduser -DHS match_state
RUN chown -R match_state:match_state /app

WORKDIR /app/srcs
RUN grpc_tools_ruby_protoc -I ./protos --ruby_out=./protos --grpc_out=./protos match_state_app.proto

USER match_state
EXPOSE 8080 50051
# VOLUME []

ENTRYPOINT ["ruby", "main.rb"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD [#TODO websocket ping]