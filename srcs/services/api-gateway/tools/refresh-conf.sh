#!/bin/ash

echo "Reloading configuration"

if api-gateway -t; then
    echo "Configuration is valid. Reloading service..."
    api-gateway -s reload
else
    echo "Configuration is invalid. Not reloading service."
fi
