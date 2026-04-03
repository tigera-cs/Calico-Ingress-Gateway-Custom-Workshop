#!/bin/bash

export GATEWAY_IP=$(kubectl get gateway/sticky-gateway -o jsonpath='{.status.addresses[0].value}')
COOKIE_JAR="consistent_hash_cookies.txt"

echo "=== UC2: Sticky Sessions - HTTPS Test Suite ==="
echo "--------------------------------------------------------"
echo "GATEWAY_IP: $GATEWAY_IP"
echo "Host: sticky.example.com"
echo "--------------------------------------------------------"

# --- PART 1: Initial Connectivity Test ---
echo "Step 1: Testing initial connectivity (Raw Header Response)..."
echo "--------------------------------------------------------"
# We fetch only the headers (-I) and print the raw output
curl -k -s -I --resolve sticky.example.com:443:$GATEWAY_IP https://sticky.example.com/

echo "--------------------------------------------------------"
echo "Pausing for 5 seconds to establish session..."
sleep 5

# --- PART 2: Establish the Sticky Session ---
echo "Step 2: Getting initial Hash Cookie..."

# Get the cookie header for the audience
SET_COOKIE=$(curl -k -s -I --resolve sticky.example.com:443:$GATEWAY_IP https://sticky.example.com/ | grep -i "set-cookie")

# Get the pod name for the script logic
FIRST_POD=$(curl -k -s -c $COOKIE_JAR --resolve sticky.example.com:443:$GATEWAY_IP https://sticky.example.com/ | jq -r '.environment.POD_NAME')

echo "Initial Target Pod: $FIRST_POD"
echo "Cookie Assigned: $SET_COOKIE"
echo "--------------------------------------------------------"

# --- PART 3: Verify Persistence ---
echo "Step 3: Verifying Persistence (10 requests)..."
for i in {1..10}; do
  NEXT_POD=$(curl -k -s -b $COOKIE_JAR --resolve sticky.example.com:443:$GATEWAY_IP \
    https://sticky.example.com/ | jq -r '.environment.POD_NAME')
  
  if [ "$NEXT_POD" == "$FIRST_POD" ]; then
    echo "Request $i: [STICK] -> $NEXT_POD"
  else
    echo "Request $i: [FAIL ] -> $NEXT_POD (Session Broke!)"
  fi
done

# Cleanup
[ -f $COOKIE_JAR ] && rm $COOKIE_JAR

echo "--------------------------------------------------------"
echo "Test Complete."