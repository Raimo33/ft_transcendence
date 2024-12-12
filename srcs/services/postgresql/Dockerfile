# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 12:03:18 by craimond          #+#    #+#              #
#    Updated: 2024/12/12 19:29:32 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM alpine:3.19

SHELL ["/bin/ash", "-c"]

RUN apk add --no-cache postgresql postgresql-dev

RUN mkdir -p /var/lib/postgresql/data

COPY ./build/postgresql.conf      /etc/postgresql/postgresql.conf
COPY ./build/init_tables.sql      /tmp/init_tables.sql
COPY ./build/init_partitions.sql  /tmp/init_partitions.sql
COPY ./build/init_triggers.sql    /tmp/init_triggers.sql
COPY ./build/init_rbac.sql        /tmp/init_rbac.sql

RUN chown -R postgres:postgres /var/lib/postgres/data

USER postgres

RUN initdb
RUN pg_ctl -o "-c config_file=/etc/postgresql/postgresql.conf" -w start

RUN psql -f /tmp/init_tables.sql
RUN psql -f /tmp/init_partitions.sql
RUN psql -f /tmp/init_triggers.sql
RUN psql -f /tmp/init_rbac.sql

RUN pg_ctl -m fast -w stop
RUN rm -rf /tmp/

EXPOSE 5432
VOLUME ["/var/lib/postgresql/data"]

ENTRYPOINT ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["pg_isready"]