#!/bin/bash

export GATEWAY_LB_DEMO=$(kubectl get gateway/load-balancing-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_LB_DEMO is: $GATEWAY_LB_DEMO"


echo ""
echo " === Generating traffic .... 100 Req (`date`) === "
for i in `seq 100`; do
    curl -s -H "Host: www.example.com" --cookie "FooBar=1.2.3.4" http://$GATEWAY_LB_DEMO/cookie | grep pod
done | sort | uniq -c

echo ""
echo "Checking the result in the pods log"
kubectl get pods -l app=backend --no-headers -o custom-columns=":metadata.name" | while read -r pod; do echo "$pod: received $(($(kubectl logs $pod | wc -l) - 2)) requests"; done

echo "done!"
