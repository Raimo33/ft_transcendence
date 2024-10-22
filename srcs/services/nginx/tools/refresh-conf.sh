#!/bin/ash

echo "Reloading configuration"

if nginx -t; then
    echo "Configuration is valid. Reloading Nginx..."
    nginx -s reload
else
    echo "Configuration is invalid. Not reloading Nginx."
fi