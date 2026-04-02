#!/bin/bash

export GATEWAY_TCP_DEMO=$(kubectl get gateway/tcp-routing-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_TCP_DEMO is: $GATEWAY_TCP_DEMO"

sleep 2 
echo ""
echo "============= Test 1: Foo service =============="
sleep 2
curl -i "http://${GATEWAY_TCP_DEMO}:8088"

echo ""
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo " 5 sec sleep "
sleep 5 

echo ""
echo "============= Test 2: bar service =============="
sleep 2
curl -i "http://${GATEWAY_TCP_DEMO}:8089"

echo "done!"
