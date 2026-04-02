#!/bin/bash

export GATEWAY_EXTERNAL_IP=$(kubectl get gateway/keepalive-timeout-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_EXTERNAL_IP is: $GATEWAY_EXTERNAL_IP"


echo ""
echo "------------------------------------------------------------------------------------------------------"
echo "===Test 1-  Keep-Alive Stress Test (200 requests, concurrency 20) ==="
echo "------------------------------------------------------------------------------------------------------"
sleep 2 
    hey -n 200 -c 20 -host "app.example.com" http://$GATEWAY_EXTERNAL_IP/



echo "Do you want to proceed to Test 2 - Keep-Alive Disabled? (y/n)"
read -r answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "✅ Proceeding..."
    echo ""
	echo "------------------------------------------------------------------------------------------------------"
	echo "===Test 2- Keep-Alive Disabled - Stress Test (200 requests, concurrency 20) ==="
	echo "------------------------------------------------------------------------------------------------------"
	sleep 3
    	hey -n 200 -c 20 -host "app.example.com" --disable-keepalive http://$GATEWAY_EXTERNAL_IP/
else
    echo "❌ Operation cancelled by user."
    exit 0
fi


echo ""
echo "Tests done!"
