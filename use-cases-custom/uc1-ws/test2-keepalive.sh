#!/bin/bash

export GATEWAY_EXTERNAL_IP=$(kubectl get gateway/keepalive-timeout-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_EXTERNAL_IP is: $GATEWAY_EXTERNAL_IP"

# Force the environment to accept the handshake
export GODEBUG=x509ignoreCN=0 

echo ""
echo "-----------------------------------------------------------------------"
echo "=== Test 1: Keep-Alive Stress Test (HTTPS) ==="
echo "-----------------------------------------------------------------------"
sleep 2 

# Remove -insecure since your version doesn't support it. 
# If it still fails with 'certificate signed by unknown authority', 
# we may need to use 'curl' in a loop or install a version of 'hey' that supports it.
hey -n 200 -c 20 -host "app.example.com" https://$GATEWAY_EXTERNAL_IP/

echo ""
echo "Do you want to proceed to Test 2? (y/n)"
read -r answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "✅ Proceeding..."
    echo ""
    echo "-----------------------------------------------------------------------"
    echo "=== Test 2: Keep-Alive Disabled (HTTPS) ==="
    echo "-----------------------------------------------------------------------"
    sleep 3
    hey -n 200 -c 20 -host "app.example.com" --disable-keepalive https://$GATEWAY_EXTERNAL_IP/
else
    echo "❌ Operation cancelled."
    exit 0
fi