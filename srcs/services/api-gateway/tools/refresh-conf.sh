#!/bin/ash

PID_FILE=/run/api-gateway.pid
PID= $(cat "$PID_FILE")

echo "Reloading api-gateway configuration"
kill -HUP $PID
