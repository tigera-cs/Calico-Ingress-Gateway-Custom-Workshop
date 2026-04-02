#!/bin/bash

export GATEWAY_STICKY_DEMO=$(kubectl get gateway/sticky-session-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_STICKY_DEMO is: $GATEWAY_STICKY_DEMO"

HEADER=$(curl --verbose http://$GATEWAY_STICKY_DEMO/get 2>&1 | grep "session-a" | awk '{print $3}')
echo "HEADER is: $HEADER"

echo ""
echo " === Generating traffic .... 5 Req (`date`) === "
for i in `seq 5`; do
    curl -H "Session-A: $HEADER" http://$GATEWAY_STICKY_DEMO/get 2>/dev/null | grep pod
done

echo "done!"
