#!/bin/ash

if [ -z "$1" ]; then
  echo "Usage: $0 <template_file>"
  exit 1
fi

TEMPLATE_FILE=$1
CONF_FILE="${TEMPLATE_FILE%.template}"

envsubst < "$TEMPLATE_FILE" > "$CONF_FILE"
rm -f "$TEMPLATE_FILE"