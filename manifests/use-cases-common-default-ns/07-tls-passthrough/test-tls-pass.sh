#!/bin/bash

export GATEWAY_TLS_DEMO=$(kubectl get gateway/tls-passthrough-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_TLS_DEMO is: $GATEWAY_TLS_DEMO"

# commented out for AKS env
#export GW_TLS_IP=$(dig +short $GATEWAY_TLS_DEMO)
#echo "GW_TLS_IP is: $GW_TLS_IP"
#sleep 3 

echo ""
echo " === Generating traffic .... (`date`) === "
sleep 2
#curl -v -H "Host:passthrough.example.com" --resolve "passthrough.example.com:6443:${GW_TLS_IP}" \
#--cacert example.com.crt https://passthrough.example.com:6443/get

# for AKS env use this
curl -v -H "Host:passthrough.example.com" --resolve "passthrough.example.com:6443:${GATEWAY_TLS_DEMO}" \
--cacert example.com.crt https://passthrough.example.com:6443/get

echo ""
echo " ========================"
echo "  done!"
echo " ========================"
