#!/bin/bash
#EXTERNAL_IP=$(kubectl get service -n tigera-gateway -l gateway.envoyproxy.io/owning-gateway-name=canary-deployment-gateway \
#  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
#echo "Gateway External IP: $EXTERNAL_IP"

export GATEWAY_CANARY_DEMO=$(kubectl get gateway/canary-deployment-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_CANARY_DEMO is: $GATEWAY_CANARY_DEMO"

echo ""
echo " === Generating traffic .... 100 Req (`date`) === "

for i in {1..100}; do
  curl -s http://$GATEWAY_CANARY_DEMO/ | grep "<h1>" 
done | sort | uniq -c

echo ""
echo " # Test Completed! "

