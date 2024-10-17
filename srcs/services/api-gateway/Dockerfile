# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/13 18:07:59 by craimond          #+#    #+#              #
#    Updated: 2024/10/14 18:28:32 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache ruby ruby-json

COPY ./app /app

RUN adduser -DHS api-gateway
RUN chown -R api-gateway:api-gateway /app

WORKDIR /app
USER api-gateway
# EXPOSE 
# VOLUME []

CMD ["ruby", "main.rb"]

# HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD 
