#!/bin/bash

echo ""
export GATEWAY_SNI_DEMO=$(kubectl get gateway/sni-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_SNI_DEMO is: $GATEWAY_SNI_DEMO"

export GW_SNI_IP=$(dig +short $GATEWAY_SNI_DEMO)
echo "GW_SNI_IP is: $GW_SNI_IP"

echo ""
echo " === Test 3: with certificate ==="
echo " === ROUND 1 === "
echo " === Generating traffic to Host www.example.com .... (`date`) === "
sleep 5 

# for AWS use this
#curl -v -H Host:www.example.com --resolve "www.example.com:443:${GW_SNI_IP}" \
#--cacert example.com.crt https://www.example.com/get -I

# for AKS use this
curl -v -H Host:www.example.com --resolve "www.example.com:443:${GATEWAY_SNI_DEMO}" \
--cacert example.com.crt https://www.example.com/get -I

echo ""
echo ""
echo ""
echo " === ROUND 2 === "
echo " === Generating traffic to Host www.SAMPLE.com .... (`date`) === "
sleep 10 

# for AWS use this
#curl -v -HHost:www.sample.com --resolve "www.sample.com:443:${GW_SNI_IP}" \
#--cacert sample.com.crt https://www.sample.com/get -I


# for AKS use this
curl -v -HHost:www.sample.com --resolve "www.sample.com:443:${GATEWAY_SNI_DEMO}" \
--cacert sample.com.crt https://www.sample.com/get -I

echo ""
echo " ========================"
echo "  Test 3: done!"
echo " ========================"
