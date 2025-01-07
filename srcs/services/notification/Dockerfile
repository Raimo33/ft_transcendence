# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/01/06 16:13:40 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 16:16:09 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache ruby protobuf

COPY ./build/Gemfile ./build/Gemfile.lock /app/

WORKDIR /app
RUN gem install bundler
RUN bundle install

COPY ./build/srcs/ /app/srcs/
COPY --from=protos notification_app.proto /app/srcs/protos/
COPY --from=certs jwtRS256.key.pub /etc/ssl/public/jwtRS256.key.pub

RUN adduser -DHS notification
RUN chown -R notification:notification /app

WORKDIR /app/srcs/
RUN grpc_tools_ruby_protoc -I ./protos --ruby_out=./protos --grpc_out=./protos notification_app.proto

USER app
EXPOSE 3000 50051
# VOLUME []

ENTRYPOINT ["ruby", "main.rb"]