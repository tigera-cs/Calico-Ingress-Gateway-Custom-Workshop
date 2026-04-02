#!/bin/bash

export GATEWAY_SNI_DEMO=$(kubectl get gateway/sni-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_SNI_DEMO is: $GATEWAY_SNI_DEMO"

echo ""
echo " === Test 1: without certificate ==="
echo " === Generating traffic to Host www.example.com .... (`date`) === "
sleep 5 
curl --verbose --header "Host: www.example.com" http://$GATEWAY_SNI_DEMO/get

echo ""
echo " ========================"
echo "  Test 1: done!"
echo " ========================"
