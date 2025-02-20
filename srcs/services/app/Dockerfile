# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 13:22:02 by craimond         ###   ########.fr        #
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
COPY --from=protos match_state_app.proto notification_app.proto /app/srcs/protos/

RUN adduser -DHS app
RUN chown -R app:app /app

WORKDIR /app/srcs/
RUN grpc_tools_ruby_protoc -I ./protos --ruby_out=./protos --grpc_out=./protos match_state_app.proto notification_app.proto

USER app
EXPOSE 3000
# VOLUME []

ENTRYPOINT ["ruby", "main.rb"]