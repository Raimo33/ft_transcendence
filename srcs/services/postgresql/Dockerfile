# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@pm.me>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2025/01/06 13:22:11 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache postgresql postgresql-dev

RUN mkdir -p /var/lib/postgresql/data

COPY ./build/postgresql.conf      /etc/postgresql/postgresql.conf
COPY ./build/init_db.sql          /tmp/init_db.sql

RUN chown -R postgres:postgres /var/lib/postgres/data

USER postgres

RUN initdb
RUN pg_ctl -o "-c config_file=/etc/postgresql/postgresql.conf" -w start
RUN psql -f /tmp/init_db.sql
RUN pg_ctl -m fast -w stop
RUN rm -rf /tmp/

EXPOSE 5432
VOLUME ["/var/lib/postgresql/data"]

ENTRYPOINT ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]