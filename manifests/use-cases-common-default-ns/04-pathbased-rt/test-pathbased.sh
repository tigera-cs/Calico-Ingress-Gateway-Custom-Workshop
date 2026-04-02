#!/bin/bash

export GATEWAY_HTTP_DEMO=$(kubectl get gateway/http-routing-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_HTTP_DEMO is: $GATEWAY_HTTP_DEMO"

echo ""
echo "===================================================="
echo " === Test 1: HTTP routing to the example backend === "
echo " === Generating traffic .... 100 Req (`date`) === "
echo "Result:"
for i in {1..100}; do
curl -s -H "Host: example.com" http://$GATEWAY_HTTP_DEMO/ | grep pod
done | sort | uniq -c

echo "      Traffic was routed to the example backend service"
sleep 5


echo ""
echo "===================================================="
echo " === Test 2: HTTP routing to the foo-svc backend ==="
echo " === Generating traffic .... 100 Req (`date`) === "
echo "Result:"
for i in {1..100}; do
curl -s -H "Host: foo.example.com" http://$GATEWAY_HTTP_DEMO/login | grep pod
done | sort | uniq -c

echo "      Traffic was routed to the foo backend service"
sleep 5

echo ""
echo "===================================================="
echo " === Test 3: HTTP routing to the bar-svc backend ==="
echo " === Generating traffic .... 100 Req (`date`) === "
echo "Result:"
for i in {1..100}; do
curl -s -H "Host: bar.example.com" http://$GATEWAY_HTTP_DEMO/ | grep pod
done | sort | uniq -c

echo "      Traffic was routed to the bar backend service"
sleep 5


echo ""
echo "===================================================="
echo " === Test 4: HTTP routing to the bar-canary-svc backend ==="
echo " === Generating traffic .... 100 Req (`date`) === "
echo "Result:"
for i in {1..100}; do
curl -s -H "Host: bar.example.com" --header "env: canary" http://$GATEWAY_HTTP_DEMO/ | grep pod
done | sort | uniq -c

echo "      Traffic was routed to the bar canary backend service"
echo "===================================================="
sleep 2 

echo "Test done!"
