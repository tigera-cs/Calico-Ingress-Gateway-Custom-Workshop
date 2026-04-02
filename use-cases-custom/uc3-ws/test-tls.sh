#!/bin/bash

export GATEWAY_TLS_DEMO=$(kubectl get gateway/tls-terminate-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_TLS_DEMO is: $GATEWAY_TLS_DEMO"

export GW_TLS_IP=$(dig +short $GATEWAY_TLS_DEMO)
echo "GW_TLS_IP is: $GW_TLS_IP"
sleep 3 

echo ""
echo " === Generating traffic .... (`date`) === "
sleep 2
curl -v -H "Host:terminate.example.com" --resolve "terminate.example.com:443:${GW_TLS_IP}" \
--cacert example.com.crt https://passthrough.example.com:6443/get

echo ""
echo " ========================"
echo "  done!"
echo " ========================"
