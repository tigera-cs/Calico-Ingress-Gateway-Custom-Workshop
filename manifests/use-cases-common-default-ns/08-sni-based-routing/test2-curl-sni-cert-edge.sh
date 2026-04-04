#!/bin/bash

export GATEWAY_SNI_DEMO=$(kubectl get gateway/sni-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_SNI_DEMO is: $GATEWAY_SNI_DEMO"

export GW_SNI_IP=$(dig +short $GATEWAY_SNI_DEMO)
echo "GW_SNI_IP is: $GW_SNI_IP"

echo ""
echo " === Test 2: with certificate ==="
echo " === Generating traffic to Host www.example.com .... (`date`) === "
sleep 5 

curl -v -HHost:www.example.com --resolve "www.example.com:443:${GW_SNI_IP}" \
--cacert example.com.crt https://www.example.com/get

echo ""
echo " ========================"
echo "  Test 2: done!"
echo " ========================"
