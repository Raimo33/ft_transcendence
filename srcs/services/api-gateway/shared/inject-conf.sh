ruby /app/main.rb -t "$CONF_FILE"

if [ $? -ne 0 ]; then
  echo "Error: api-gateway configuration test failed, check logs"
  exit 1
fi

PID_FILE=/var/run/api-gateway.pid

echo "Reload api-gateway configuration"
kill -HUP $(cat "$PID_FILE")
