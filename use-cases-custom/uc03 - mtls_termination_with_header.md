# Calico Ingress Gateway -  Optional mTLS with Client Certificate Forwarding

## Overview

This example demonstrates how to implement **optional mutual TLS (mTLS)** with client certificate forwarding using Gateway API on Calico Ingress Gateway.

It replaces the NGINX Ingress mTLS annotations while supporting both clients with and without certificates on the same hostname.

### Original NGINX Ingress Annotations

```yaml
annotations:
  nginx.ingress.kubernetes.io/auth-tls-pass-certificate-to-upstream: "true"
  nginx.ingress.kubernetes.io/auth-tls-secret: ingress-mtls/ca-secret
  nginx.ingress.kubernetes.io/auth-tls-verify-client: optional_no_ca
  nginx.ingress.kubernetes.io/auth-tls-verify-depth: "1"
  nginx.ingress.kubernetes.io/configuration-snippet: |
    proxy_set_header X_FORWARDED_CLIENT_CERT $ssl_client_escaped_cert;
```

We are using a dedicated Gateway and namespace (`uc3-custom`) to keep this example independent from Example 1.

### Real-World Use Cases

- API Security with Gradual Rollout: Services that want to enforce mTLS for internal/automated clients while still supporting external/browser clients during migration.
- Zero-Trust Architectures: Applications that need to validate client certificates and forward them to the backend for additional authorization or auditing.
- Regulatory Compliance: Workloads in finance or healthcare that require strong client authentication while maintaining flexibility.



### High Level Tasks

- Create Namespace + Backend (Deployment + Service) in uc3-custom
- Create dedicated mTLS Gateway in default namespace (port 443)
- Create ClientTrafficPolicy for optional mTLS
- Create HTTPRoute with client certificate header forwarding

---


### Diagram

                      External Clients
                              │
                              │ HTTPS / HTTP Traffic (mTLS)
                              ▼
    +-------------------------------------------------------------+
    |                      Kubernetes Cluster                     |
    |                                                             |
    |  +------------------+          +---------------------+      |
    |  |   default NS     |          |    uc3-custom NS    |      |
    |  |                  |          |                     |      |
    |  |  [Gateway]       |<-------->|  [HTTPRoute]        |      |
    |  |  mtls-gateway    |          |                     |      |
    |  |                  |          |  backendRefs ->     |      |
    |  |  ClientTraffic   |          |     [uc3-backend]   |      |
    |  |  Policy          |          |     Deployment      |      |
    |  |                  |          |     Service         |      |
    |  +------------------+          +---------------------+      |
    |                                                             |
    +-------------------------------------------------------------+

---

**Key Points**:

- The Gateway terminates TLS and optionally requests a client certificate (`optional_no_ca` behavior).
- The client certificate (when presented) is forwarded to the backend via the `X-Forwarded-Client-Cert` header.
- Both certificate-based and non-certificate clients can connect to the same hostname.


### Demo

#### 1. Create a deployment named `Backend` which we will use to test sticky session / session persistence. The deployment will have 4 replicas.

  ```
  kubectl apply -f - <<EOF
  apiVersion: v1
  kind: Namespace
  metadata:
    name: uc3-custom
  ---
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: uc3-backend
    namespace: uc3-custom
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: uc3-backend
    namespace: uc3-custom
    labels:
      app: uc3-backend
      service: uc3-backend
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
    replicas: 4
    selector:
      matchLabels:
        app: uc3-backend
    template:
      metadata:
        labels:
          app: uc3-backend
      spec:
        serviceAccountName: uc3-backend
        containers:
        - name: uc3-backend
          image: ealen/echo-server:latest
          ports:
          - containerPort: 80
          env:
          - name: POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
  EOF
  ```

#### 2. Create a Gateway resource using the "tigera-gateway-class"

  ```
  kubectl apply -f - <<EOF
  apiVersion: gateway.networking.k8s.io/v1
  kind: Gateway
  metadata:
    name: sticky-session-gateway
    namespace: default
  spec:
    gatewayClassName: tigera-gateway-class
    listeners:
    - name: uc3-http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
  EOF
  ```


#### 3. Create the HTTPRoute and Traffic Policy
  ```
  kubectl apply -f - <<EOF
  apiVersion: gateway.envoyproxy.io/v1alpha1
  kind: BackendTrafficPolicy
  metadata:
    name: uc3-custom-session-affinity
    namespace: uc3-custom
  spec:
    targetRef:
      group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: uc3-custom
    loadBalancer:
      type: ConsistentHash
      consistentHash:
        type: Cookie
        cookie:
          name: route
          attributes:
            path: /
            sameSite: Lax
          ttl: 14400s
  ---
  apiVersion: gateway.networking.k8s.io/v1
  kind: HTTPRoute
  metadata:
    name: sticky-session-route
    namespace: uc3-custom
  spec:
    parentRefs:
    - name: sticky-session-gateway
      namespace: default
      sectionName: uc3-http
    hostnames:
    - "app.example.com"
    rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
      - name: uc3-backend
        port: 3000
  EOF
  ```

#### 4. Wait for 30 seconds to allow services and gateway to be ready

  ```
  sleep 30
  ```

#### 5. Retrieve the external IP of the gateway

  ```
  export GATEWAY_EXTERNAL_IP=$(kubectl get gateway/sticky-session-gateway -o jsonpath='{.status.addresses[0].value}')
  echo "GATEWAY_EXTERNAL_IP is: $GATEWAY_EXTERNAL_IP"
  ```

### 6. Test

## sticky session

**Expected Behavior**:
- Clients without a certificate are allowed (`optional_no_ca`).
- Clients with a valid client certificate have it forwarded to the backend in the `X-Forwarded-Client-Cert` header.
- The backend can see and process the client certificate information.

**Test Command** (to verify stickiness):
  ```
  # 1. Test without client certificate (should succeed)
  curl -v -H "Host: terminate.example.com" https://terminate.example.com/ \
    | jq -r '.environment.POD_NAME // "No POD_NAME found"'

  # 2. Test with client certificate (when you have one)
  curl -v --cert client-cert.pem --key client-key.pem \
    -H "Host: terminate.example.com" https://terminate.example.com/ \
    | jq -r '.headers | select(.["x-forwarded-client-cert"] != null)'
  ```



---


### Key Observations

- The Gateway successfully requests a client certificate optionally without breaking non-mTLS clients.
- When a client certificate is presented, it is properly forwarded to the backend in the expected header (X-Forwarded-Client-Cert).
- The verifyDepth: 1 and optional mode match the original NGINX auth-tls-verify-client: optional_no_ca behavior.

### Configuration Used
This mTLS setup was achieved using:

- `ClientTrafficPolicy`:
  - `tls.clientCertificate.type: Optional`
  - `tls.clientCertificate.verifyDepth: 1`
  - `tls.clientCertificate.caCertificateRef`

- `HTTPRoute with `RequestHeaderModifier` filter to forward:
`X-Forwarded-Client-Cert`: `%DOWNSTREAM_PEER_CERTIFICATE%`


This replaces the original NGINX annotations:

- `nginx.ingress.kubernetes.io/auth-tls-verify-client: optional_no_ca`
- `nginx.ingress.kubernetes.io/auth-tls-pass-certificate-to-upstream`
- `Custom configuration-snippet for header forwarding`

---
####  Conclusion: <To add>
---


---
### Clean-up

#### 1. Delete app, service, serviceAccount, HTTPRoute and Gateway

  ```
  NS=uc3-custom
  kubectl delete ServiceAccount uc3-backend -n $NS 
  kubectl delete service uc3-backend -n $NS
  kubectl delete deployment uc3-backend -n $NS
  kubectl delete gateway sticky-session-gateway -n default
  kubectl delete HTTPRoute sticky-session-route -n $NS
  kubectl delete backendtrafficpolicies uc3-custom-session-affinity -n $NS
  kubectl delete ns $NS 
  ```

===
> **Congratulations! You have completed `Calico Ingress Gateway Workshop - mTLS connectivity  `!**

---
**Credits:** Portions of this guide are based on or derived from the [Envoy Gateway documentation](https://gateway.envoyproxy.io/docs/tasks/traffic/session-persistence/).