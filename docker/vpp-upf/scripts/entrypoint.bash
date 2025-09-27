#!/bin/bash

set -euo pipefail

# Replace environment variables in the startup configuration file
envsubst < /etc/vpp/startup.conf.tmpl > /etc/vpp/startup.conf
envsubst < /etc/vpp/init.conf.tmpl > /etc/vpp/init.conf

echo "Starting VPP..."
vpp -c /etc/vpp/startup.conf | tee /var/log/vpp/output.log &

# Wait for VPP process
until pgrep -x vpp_main > /dev/null; do
    echo "Waiting for VPP process..."
    sleep 2
done

# Wait until GTPU endpoints exist
until [ "$(vppctl show upf gtpu endpoint | grep -c 'IP4')" -gt 0 ]; do
    echo "Waiting for VPP UPF GTPU endpoints..."
    sleep 2
done

SEP="========================"

echo "✅ VPP is up and running!"

echo "$SEP VPP INFO $SEP"
vppctl show version
printf "\n"

echo "$SEP UPF GTPU INFO $SEP"
vppctl show upf gtpu endpoint
printf "\n"

echo "$SEP UPF PFCP INFO $SEP"
vppctl show upf specification release
vppctl show upf pfcp endpoint
vppctl show upf node-id
printf "\n"

tail -f /var/log/vpp/output.log