
# Calico Ingress Gateway - Mutual TLS (mTLS) with Client Certificate Forwarding

### Table of Contents

* [Overview](#overview)
* [High Level Tasks](#high-level-tasks)
* [Diagram](#diagram)
* [Step-by-Step Demo](#demo)
* [Key Observations](#key-observations)
* [Clean-up](#clean-up)

### Overview
This example demonstrates how to implement Mutual TLS (mTLS) and client certificate header forwarding using the Gateway API on Calico Ingress Gateway.

In this scenario, the Gateway acts as a security gatekeeper: it terminates the TLS connection, validates the client's identity against a trusted Certificate Authority (CA), and injects the certificate metadata into headers before forwarding the request to the backend. This setup provides a standardized, cloud-native replacement for complex NGINX Ingress annotations.

#### Original NGINX Ingress Annotations
```YAML
  annotations:
    nginx.ingress.kubernetes.io/auth-tls-pass-certificate-to-upstream: "true"
    nginx.ingress.kubernetes.io/auth-tls-secret: ingress-mtls/ca-secret
    nginx.ingress.kubernetes.io/auth-tls-verify-client: "on"
    nginx.ingress.kubernetes.io/auth-tls-verify-depth: "1"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_set_header X-Forwarded-Client-Cert $ssl_client_escaped_cert;
```

### Real-World Use Cases
- **Zero-Trust Architectures**: Enforcing identity verification at the network edge so that only authenticated devices with valid certificates can reach internal services.
- **B2B API Security**: Providing a secure handoff for partner organizations where authentication is handled at the transport layer (L4/L7) rather than application-level API keys.
- **Legacy Migration**: Transitioning from NGINX-based mTLS to Gateway API while maintaining the ability for backends to see and audit client certificate details.

### High Level Tasks
- Generate Certificates and Kubernetes Secrets for the Gateway and Client CA.
- Create Namespace + Backend (Deployment + Service) in `uc3-custom`.
- Create a dedicated HTTPS Gateway in the `default` namespace (Port 443) with `frontendValidation`.
- Create an HTTPRoute and a `ClientTrafficPolicy` with a `xForwardedClientCert` filter to inject client certificate details.

---

### Diagram
```text
    Kubernetes Cluster Boundary
    +--------------------------------------------------------------------------------------+
    |                                                                                      |
    |    default namespace                                     uc3-custom namespace        |
    |  +-----------------------+                          +--------------------------+     |
    |  |                       |                          |                          |     |
    |  |      [Gateway]        |        1. Bind           |      [HTTPRoute]         |     |
    |  |    (mtls-gateway)     |<------------------------>|      (mtls-route)        |     |
    |  |                       |                          |                          |     |
    |  |  +-----------------+  |                          |  +--------------------+  |     |
    |  |  | TLS Termination |  |        2. Forward        |  |    [uc3-backend]   |  |     |
    |  |  +-----------------+  |------------------------->|  |   (Service/Pod)    |  |     |
    |  |  | Client Cert     |  |   (with X-F-C-C Header)   |  +--------------------+  |     |
    |  |  | Validation      |  |                          |             ^            |     |
    |  |  +-----------------+  |                          |             |            |     |
    |  |  | Inject X-F-C-C  |  |                          |      [Receives Header]   |     |
    |  |  | Header          |  |                          |                          |     |
    |  |  +-----------------+  |                          +--------------------------+     |
    |  |                       |                                                           |
    +--+-----------^-----------+-----------------------------------------------------------+
                  |
                  | 
      mTLS Handshake (Mandatory/Optional Client Cert)
                  |
                  |
          +-----------------+
          | External Client |
          | (with/without   |
          |  Client Cert)   |
          +-----------------+

    ----------------------------------------------------------------------------------------
    LEGEND & FLOW:
    1. Client initiates HTTPS; Gateway requests Client Cert.
    2. Gateway terminates TLS and validates cert against trusted CA (client-ca-cert).
    3. Gateway extracts cert metadata and injects 'X-Forwarded-Client-Cert' header.
    4. HTTPRoute rules direct traffic to the uc3-backend pod in the custom namespace.
    ----------------------------------------------------------------------------------------
```
---

### Demo

#### 1. Generate Certificates and Secrets
First, we create the Server certificate for the Gateway and the CA/Client certificate pair for the mTLS handshake.

```bash
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
```

#### 2. Create the Backend Deployment
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: uc3-custom
---
apiVersion: v1
kind: Service
metadata:
  name: uc3-backend
  namespace: uc3-custom
spec:
  ports:
    - name: http
      port: 3000
      targetPort: 80
  selector:
    app: uc3-backend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: uc3-backend
  namespace: uc3-custom
spec:
  replicas: 2
  selector:
    matchLabels:
      app: uc3-backend
  template:
    metadata:
      labels:
        app: uc3-backend
    spec:
      containers:
      - name: uc3-backend
        image: ealen/echo-server:latest
        ports:
        - containerPort: 80
EOF
```

#### 3. Create the Gateway with frontendValidation
Note: This uses the strict schema required for modern Gateway API v1.

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: mtls-gateway
  namespace: default
spec:
  gatewayClassName: tigera-gateway-class
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: terminate.example.com
    tls:
      mode: Terminate
      certificateRefs:
      - name: terminate-example-tls-cert
    allowedRoutes:
      namespaces:
        from: All
EOF
```

#### 4. Create the HTTPRoute and ClientTrafficPolicy with Header Forwarding
```bash
kubectl apply -f - <<EOF
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: ClientTrafficPolicy
metadata:
  name: mtls-client-cert-forward
  namespace: default
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: mtls-gateway
  tls:
    clientValidation:
      caCertificateRefs:
      - kind: ConfigMap
        group: ""
        name: client-ca-cert
  headers:
    xForwardedClientCert:
      mode: SanitizeSet
      certDetailsToAdd:
      - Subject
      - URI
      - DNS
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: mtls-route
  namespace: uc3-custom
spec:
  parentRefs:
  - name: mtls-gateway
    namespace: default
  hostnames:
  - "terminate.example.com"
  rules:
  - backendRefs:
    - name: uc3-backend
      port: 3000
EOF
```

#### 5. Verify and Test
Wait for the Gateway to receive an IP address:
```bash
export GATEWAY_IP=$(kubectl get gateway mtls-gateway -o jsonpath='{.status.addresses[0].value}')
echo "Gateway IP: $GATEWAY_IP"
```

**Test Command (mTLS Handshake + Header Check):**
```bash
curl -v -k --resolve "terminate.example.com:443:$GATEWAY_IP" \
  --cert client.crt --key client.key \
  https://terminate.example.com/ | jq '.request.headers | with_entries(select(.key | startswith("x-")))'
```

---

### Key Observations

- **Handshake Verification**: The Gateway successfully performs a full mTLS handshake.
- **ClientTrafficPolicy** — enforces mTLS (client cert validation)
- **Header Injection**: The `ClientTrafficPolicy` successfully injects `x-Forwarded-Client-Cert` into the request received by the backend.
- **Protocol Security**: Identity verification is handled entirely by the Calico Ingress (Envoy), offloading complex cryptographic validation from the application code.

### Configuration Used
- **ClientTrafficPolicy & Gateway `tls.clientValidation`**: Establishes the trust anchor by referencing the `client-ca-cert` secret.
- **ClientTrafficPolicy `x-Forwarded-Client-Cert`**: Replaces custom NGINX snippets with a declarative filter to signal mTLS status to upstreams.

---

### Conclusion
By implementing mTLS via the Gateway API, we have centralized identity management at the infrastructure layer. This setup ensures that only verified clients can reach the backend while providing the application with standard HTTP headers for auditing and fine-grained authorization. This transition from NGINX annotations to the Gateway API provides a more robust, vendor-neutral security model that is natively understood by the Kubernetes control plane.

---

### Clean-up
```bash
kubectl delete gateway mtls-gateway -n default --ignore-not-found
kubectl delete clienttrafficpolicy mtls-optional-policy -n default --ignore-not-found
kubectl delete httproute mtls-route -n uc3-custom --ignore-not-found
kubectl delete namespace uc3-custom --ignore-not-found

# Optional: Clean certificates
kubectl delete secret terminate-example-tls-cert -n default --ignore-not-found
kubectl delete configmap client-ca-cert -n default --ignore-not-found
```

===
> **Congratulations! You have completed `Calico Ingress Gateway Workshop - mTLS connectivity`!**