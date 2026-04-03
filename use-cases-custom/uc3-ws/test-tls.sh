#!/bin/bash

export GATEWAY_IP=$(kubectl get gateway mtls-gateway -o jsonpath='{.status.addresses[0].value}')
echo "Gateway IP: $GATEWAY_IP"



# Test with client cert — should succeed (optional_no_ca)
echo ""
echo " === Test mTLS Handshake + Header Check — should succeed (optional_no_ca).... (`date`) === "
echo ""
echo "Do you want to proceed (y/n)"
read -r answer

if [[ "$answer" =~ ^[Yy]$ ]]; then

curl -v -k --resolve "terminate.example.com:443:$GATEWAY_IP" \
  --cert client.crt --key client.key \
  https://terminate.example.com/ | jq '.request.headers | with_entries(select(.key | startswith("x-")))'

else
    echo "❌ Operation cancelled by user."
    exit 0
fi

# Expected: 200 OK, XFCC header


echo ""
echo " ========================"
echo "  done!"
echo " ========================"
