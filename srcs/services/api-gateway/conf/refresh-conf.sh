#!/bin/ash

PID_FILE=/var/run/api-gateway.pid

echo "Reloading api-gateway configuration"
kill -HUP $(cat "$PID_FILE")
