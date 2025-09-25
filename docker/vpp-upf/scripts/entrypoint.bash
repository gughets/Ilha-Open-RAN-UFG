#!/bin/bash

set -euo pipefail

# Replace environment variables in the startup configuration file
envsubst < /etc/vpp/startup.conf.tmpl > /etc/vpp/startup.conf
envsubst < /etc/vpp/init.conf.tmpl > /etc/vpp/init.conf

echo "Starting VPP..."
vpp -c /etc/vpp/startup.conf

# Wait for VPP process
until pgrep -x vpp_main > /dev/null; do
    echo "Waiting for VPP process..."
    sleep 2
done

# Wait for VPP CLI
until vppctl show version &>/dev/null; do
    echo "Waiting for VPP CLI..."
    sleep 2
done

SEP="=================================================="

echo "✅ VPP is up and running!"
echo "$SEP"
echo "VPP Info:"
vppctl -s /run/vpp/cli.sock show version
echo "$SEP"

echo "UPF GTPU Info:"
vppctl -s /run/vpp/cli.sock show upf gtpu endpoint
echo "$SEP"

echo "UPF PFCP Info:"
vppctl -s /run/vpp/cli.sock show upf specification release
vppctl -s /run/vpp/cli.sock show upf pfcp endpoint
vppctl -s /run/vpp/cli.sock show upf node-id
echo "$SEP"

# Mantém o container vivo
sleep infinity