#!/bin/bash

# Configure Tiers
echo ""
echo "----------------------------"
echo "- Configure Tiers"
echo "----------------------------"


# Default tier policies
echo "# deploy Default tier Staged Deny policies"

kubectl apply -f -<<EOF
apiVersion: projectcalico.org/v3
kind: StagedGlobalNetworkPolicy
metadata:
  name: default.default-deny
spec:
  tier: default
  order: 10000
  ingress:
    - action: Deny
      source: {}
      destination: {}
  egress:
    - action: Deny
      source: {}
      destination: {}
  types:
    - Ingress
    - Egress
EOF

kubectl apply -f -<<EOF
apiVersion: projectcalico.org/v3
kind: Tier
metadata:
  name: security
spec:
  order: 200
---
apiVersion: projectcalico.org/v3
kind: Tier
metadata:
  name: platform
spec:
  order: 300
---
apiVersion: projectcalico.org/v3
kind: Tier
metadata:
  name: app
spec:
  order: 400
EOF

echo "# setup Security tier PASS policies"
kubectl apply -f -<<EOF
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: security.security-default-pass
spec:
  tier: security
  order: 10000
  ingress:
    - action: Pass
      source: {}
      destination: {}
  egress:
    - action: Pass
      source: {}
      destination: {}
  types:
    - Ingress
    - Egress
EOF

echo "# setup Platform tier PASS policies"
kubectl apply -f -<<EOF
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: platform.platform-default-pass
spec:
  tier: platform
  order: 10000
  ingress:
    - action: Pass
      source: {}
      destination: {}
  egress:
    - action: Pass
      source: {}
      destination: {}
  types:
    - Ingress
    - Egress
EOF

echo "# deploying the pass rule for the App tier"

kubectl apply -f -<<EOF
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: app.app-default-pass
spec:
  tier: app
  order: 10000
  ingress:
    - action: Pass
      source: {}
      destination: {}
  egress:
    - action: Pass
      source: {}
      destination: {}
  types:
    - Ingress
    - Egress
EOF

