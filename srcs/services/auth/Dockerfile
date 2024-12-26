# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2024/12/26 21:30:54 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache ruby protobuf

COPY ./build/Gemfile ./build/Gemfile.lock /app/

WORKDIR /app
RUN gem install bundler
RUN bundle install

COPY ./build/app/  /app/
COPY --from=protos \
  auth_user.proto \
  auth_api_gateway.proto \
  /app/protos/

RUN adduser -DHS auth
RUN chown -R auth:auth /app

WORKDIR /app/protos
RUN grpc_tools_ruby_protoc -I ./ --ruby_out=./ --grpc_out=./ \
  auth_user.proto \
  auth_api_gateway.proto

WORKDIR /app
USER auth
EXPOSE 50051
VOLUME ["/etc/ssl/private"]

ENTRYPOINT ["main.rb"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["healthcheck.rb"]