# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2024/11/28 05:10:06 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache ruby protobuf

COPY ./build/app/   /app

RUN adduser -DHS user
RUN chown -R user:user /app
RUN chmod -R +x /usr/local/bin/

WORKDIR /app
RUN gem install bundler
RUN bundle install
WORKDIR /app/proto
RUN protoc --ruby_out=./ auth.proto user.proto

USER user
WORKDIR /app
EXPOSE 50052

ENTRYPOINT ["main.rb"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["