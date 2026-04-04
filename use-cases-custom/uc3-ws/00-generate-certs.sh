#!/bin/bash
echo "=== UC3 mTLS Certificate Generation (Simple Version) ==="

# Cleanup old resources to avoid conflicts
echo "Cleaning up old secrets and configmaps..."
kubectl delete secret terminate-example-tls-cert -n default --ignore-not-found
kubectl delete configmap client-ca-cert -n default --ignore-not-found

# Generate certificates in current directory
echo "Generating certificates..."

# 1. CA Certificate
openssl req -x509 -newkey rsa:2048 -keyout ca.key -out ca.crt \
  -days 365 -nodes -subj "/CN=Test CA" 2>/dev/null

# 2. Server Certificate (for the Gateway)
openssl req -newkey rsa:2048 -keyout server.key -out server.csr \
  -nodes -subj "/CN=terminate.example.com" 2>/dev/null
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out server.crt -days 365 2>/dev/null

# 3. Client Certificate (for testing with --cert / --key)
openssl req -newkey rsa:2048 -keyout client.key -out client.csr \
  -nodes -subj "/CN=test-client/O=test-org" 2>/dev/null
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out client.crt -days 365 2>/dev/null

# 4. Create Kubernetes resources
kubectl create secret tls terminate-example-tls-cert \
  --cert=server.crt --key=server.key -n default

kubectl create configmap client-ca-cert \
  --from-file=ca.crt=ca.crt -n default

echo ""
echo "✅ Certificates generated and secrets created successfully!"
echo ""
echo "Files created in current directory:"
ls -l *.crt *.key 2>/dev/null
echo ""
echo "Kubernetes resources:"
echo "   • Secret (TLS)     : terminate-example-tls-cert (default namespace)"
echo "   • ConfigMap (CA)   : client-ca-cert (default namespace)"
echo ""
echo "You can now apply the Gateway, ClientTrafficPolicy, and HTTPRoute."