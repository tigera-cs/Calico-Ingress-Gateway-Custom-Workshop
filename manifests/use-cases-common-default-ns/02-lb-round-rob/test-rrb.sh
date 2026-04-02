#!/bin/bash

export GATEWAY_LB_DEMO=$(kubectl get gateway/load-balancing-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_LB_DEMO is: $GATEWAY_LB_DEMO"


echo ""
echo " === Generating traffic .... 100 Req (`date`) === "
for i in `seq 100`; do
    curl -s -H "Host: www.example.com" http://$GATEWAY_LB_DEMO/round | grep pod
done | sort | uniq -c

echo "done!"
