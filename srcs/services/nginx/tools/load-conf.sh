#!/bin/ash

if [ -z "$1" ]; then
  echo "Usage: $0 <template_file>"
  exit 1
fi

export TEMPLATE_FILE=$1
export CONF_FILE="${TEMPLATE_FILE%.template}"
export PID_FILE="/var/run/nginx.pid"

envsubst < "$TEMPLATE_FILE" > "$CONF_FILE"
nginx -t

if [ $? -ne 0 ]; then
  echo "Error: nginx configuration test failed, check logs"
  exit 1
fi

if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE"); then
  nginx -s reload
fi
