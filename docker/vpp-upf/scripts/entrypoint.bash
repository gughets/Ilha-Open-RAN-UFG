#!/bin/bash

set -euo pipefail

# Replace environment variables in the startup configuration file
envsubst < /etc/vpp/startup.conf.tmpl > /etc/vpp/startup.conf
envsubst < /etc/vpp/init.conf.tmpl > /etc/vpp/init.conf

echo "Starting VPP..."
vpp -c /etc/startup.conf &

# Wait for VPP process
until pgrep -x vpp_main > /dev/null; do
    echo "Waiting for VPP process..."
    sleep 1
done

# Wait for VPP CLI
until vppctl show version &>/dev/null; do
    echo "Waiting for VPP CLI..."
    sleep 1
done

echo "✅ VPP is up and running!"

sleep infinity