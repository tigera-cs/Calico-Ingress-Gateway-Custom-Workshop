#!/bin/bash

export GATEWAY_EXTERNAL_IP=$(kubectl get gateway/sticky-session-gateway -o jsonpath='{.status.addresses[0].value}')
echo "GATEWAY_EXTERNAL_IP is: $GATEWAY_EXTERNAL_IP"


echo ""
echo "------------------------------------------------------------------------------------------------------"
echo " Test 1 - basic connectivity                                                                          "
echo "------------------------------------------------------------------------------------------------------"
echo " === Generating traffic .... 1 Req (`date`) === "
    curl -s -H "Host: app.example.com" \
    --cookie-jar cookies.txt \
    http://$GATEWAY_EXTERNAL_IP/ \
    | jq -r '.environment.POD_NAME'


echo ""
echo "Do you want to proceed to Test 2 - multiple requests? (y/n)"
read -r answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "✅ Proceeding..."
    echo "------------------------------------------------------------------------------------------------------"
    echo -e "\n===  Test 2 - multiple times - POD_NAME should stay the same (sticky session) ==="
    echo "------------------------------------------------------------------------------------------------------"
    echo " === Generating traffic .... 5 Req (`date`) === "

  for i in {1..5}; do
    echo "Request $i:"
    curl -s -H "Host: app.example.com" \
      --cookie cookies.txt \
      http://$GATEWAY_EXTERNAL_IP/get 2>/dev/null\
      | jq -r '.environment.POD_NAME'
   done
else
    echo "❌ Operation cancelled by user."
    exit 0
fi



echo ""
echo " Tests done!"
