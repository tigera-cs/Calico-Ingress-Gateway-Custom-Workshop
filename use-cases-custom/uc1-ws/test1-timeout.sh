#!/bin/bash

export GATEWAY_EXTERNAL_IP=$(kubectl get gateway/keepalive-timeout-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_EXTERNAL_IP is: $GATEWAY_EXTERNAL_IP"


echo ""
echo "------------------------------------------------------------------------------------------------------"
echo " Test 1 - basic connectivity (Fast Request)"
echo "------------------------------------------------------------------------------------------------------"
echo " === Generating traffic .... 5 Req (`date`) === "
    time curl -v -H "Host: app.example.com" http://$GATEWAY_EXTERNAL_IP/get 2>/dev/null |  jq -r '.environment.POD_NAME' 


echo ""
echo "Do you want to proceed to Test 2 - Long Request - 60 second delay? (y/n)"
read -r answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "✅ Proceeding..."
    echo "------------------------------------------------------------------------------------------------------"
    echo -e "\n===  Test 2 - Long Request - 60 second delay (proving backendRequest timeout) ==="
    echo "          (should succeed because of the 590s backend timeout)"
    echo "------------------------------------------------------------------------------------------------------"
    echo " === Generating traffic .... Req (`date`) === "

    time curl -v --max-time 120 -H "Host: app.example.com" http://$GATEWAY_EXTERNAL_IP/?echo_time=60000  |  jq -r '.environment.POD_NAME'

else
    echo "❌ Operation cancelled by user."
    exit 0
fi



echo ""
echo " Tests done!"
