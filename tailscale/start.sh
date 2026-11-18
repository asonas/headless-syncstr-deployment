#!/bin/sh
set -eu
caddy start --config /etc/syncstr/Caddyfile --adapter caddyfile
exec /usr/local/bin/containerboot
