# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2024/12/26 21:34:12 by craimond         ###   ########.fr        #
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
  auth_user.proto \
  notification_user.proto \
  user_api_gateway.proto \
  /app/protos/

RUN adduser -DHS user
RUN chown -R user:user /app

WORKDIR /app/protos
RUN grpc_tools_ruby_protoc -I ./ --ruby_out=./ --grpc_out=./ \
  user_api_gateway.proto \
  user_auth.proto \
  user_notification.proto

WORKDIR /app
USER user
EXPOSE 50051

ENTRYPOINT ["main.rb"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["healthcheck.rb"]