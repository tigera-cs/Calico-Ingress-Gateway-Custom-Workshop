#!/bin/bash

# Hey generates concurrent requests 

export GATEWAY_LB_DEMO=$(kubectl get gateway/load-balancing-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_LB_DEMO is: $GATEWAY_LB_DEMO"


echo ""
echo " === Generating concurrent traffic .... 100 Req (`date`) === "

hey -n 100 -c 100 -host "www.example.com" http://${GATEWAY_LB_DEMO}/round
kubectl get pods -l app=backend --no-headers -o custom-columns=":metadata.name" | while read -r pod; do echo "$pod: received $(($(kubectl logs $pod | wc -l) - 2)) requests"; done

echo "done!"
