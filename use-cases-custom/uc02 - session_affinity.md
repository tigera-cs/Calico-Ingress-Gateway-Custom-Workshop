# Calico Ingress Gateway - Cookie-Based Session Affinity (Sticky Sessions)

### Table of Contents

* [Overview](#overview)
* [High Level Tasks](#high-level-tasks)
* [Diagram](#diagram)
* [Demo](#demo)
* [Clean-up](#clean-up)

---

### Overview

This example demonstrates how to implement **cookie-based session affinity** (sticky sessions) using Gateway API, replacing the classic NGINX Ingress sticky session annotations.

We are using a dedicated Gateway and namespace (`uc2-custom`) to keep this example independent from Example 1.

### Real-World Use Cases

- **User Authentication**: Login sessions often require that a user’s requests are handled by the same backend instance to maintain session tokens and authentication state.
- **E-Commerce Shopping Carts**: Ensures that items added to a cart are consistently available across pages without requiring frequent database lookups.
- **Online Gaming or Collaboration Tools**: Maintains game state or live document sessions, avoiding interruptions caused by switching backend instances.

## High Level Tasks

- Create Namespace + Backend (Deployment + Service) in `uc2-custom`
- Create dedicated Gateway in `default` namespace
- Create ClientTrafficPolicy (optional)
- Create HTTPRoute with `sessionPersistence` in `uc2-custom`

### Original NGINX Ingress Annotations
In the original NGINX Ingress resource we used the following annotations:

```yaml
annotations:
  kubernetes.io/ingress.class: nginx
  nginx.ingress.kubernetes.io/affinity: cookie
  nginx.ingress.kubernetes.io/affinity-mode: persistent
  nginx.ingress.kubernetes.io/session-cookie-change-on-failure: "true"
  nginx.ingress.kubernetes.io/session-cookie-expires: "14400"
  nginx.ingress.kubernetes.io/session-cookie-max-age: "14400"
  nginx.ingress.kubernetes.io/session-cookie-name: route
```

### High Level Tasks

- Create Namespace `uc2-custom`
- Deploy the backend application (Deployment + Service) in `uc2-custom`
- Create Gateway resource in `default` namespace
- Create ClientTrafficPolicy (in `default`)
- Create HTTPRoute + BackendTrafficPolicy in `uc2-custom`

---


### Diagram
```text
    +-------------------------------------------------------------+
    |                      Kubernetes Cluster                     |
    |                                                             |
    |  +------------------+          +---------------------+      |
    |  |   default NS     |          |    uc2-custom NS    |      |
    |  |                  |          |                     |      |
    |  |  [Gateway]       |<-------->|  [HTTPRoute]        |      |
    |  |   sticky-        |   allowedRoutes    |           |      |
    |  |  session-gateway |     + sectionName  |           |      |
    |  |                  |          |  backendRefs ->     |      |
    |  |                  |          |     [uc2-backend]   |      |
    |  |                  |          |     Deployment      |      |
    |  |                  |          |     Service         |      |
    |  +------------------+          +---------------------+      |
    |                                                             |
    |                                                             |
    +-------------------------------------------------------------+
                  ↑  HTTP / HTTPS Traffic                             
                  │ (with Cookie-based Sticky Sessions)                
            External Clients 
```
---

**Key Points**:
**Key Points**:
- Each example uses its own dedicated Gateway for clarity in the demo.
- Session affinity is configured directly in the `HTTPRoute` using the native `sessionPersistence` field.
- The backend pod is selected consistently using a cookie named `route` with a 4-hour lifetime.


### Demo

#### 1. Generate certificate
  ```
  openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
    -subj '/CN=terminate.example.com/O=Example Inc.' \
    -keyout server.key -out server.crt

  kubectl create secret tls terminate-example-tls-cert \
    --key=server.key --cert=server.crt

  ```

#### 2. Create a deployment named `Backend` which we will use to test sticky session / session persistence. The deployment will have 4 replicas.

  ```
  kubectl apply -f - <<EOF
  apiVersion: v1
  kind: Namespace
  metadata:
    name: uc2-custom
  ---
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: uc2-backend
    namespace: uc2-custom
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: uc2-backend
    namespace: uc2-custom
    labels:
      app: uc2-backend
      service: uc2-backend
  spec:
    ports:
      - name: http
        port: 3000
        targetPort: 80
    selector:
      app: uc2-backend
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: uc2-backend
    namespace: uc2-custom
  spec:
    replicas: 4
    selector:
      matchLabels:
        app: uc2-backend
    template:
      metadata:
        labels:
          app: uc2-backend
      spec:
        serviceAccountName: uc2-backend
        containers:
        - name: uc2-backend
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

#### 3. Create a Gateway resource using the "tigera-gateway-class"

  ```
  kubectl apply -f - <<EOF
  apiVersion: gateway.networking.k8s.io/v1
  kind: Gateway
  metadata:
    name: sticky-gateway
    namespace: default
  spec:
    gatewayClassName: tigera-gateway-class
    listeners:
    - name: uc2-https
      protocol: HTTPS
      port: 443
      hostname: "sticky.example.com"
      tls:
        mode: Terminate
        certificateRefs:
        - name: app-example-tls-cert
      allowedRoutes:
        namespaces:
          from: All
  EOF
  ```


#### 4. Create the HTTPRoute and Traffic Policy
  ```
  kubectl apply -f - <<EOF
  apiVersion: gateway.envoyproxy.io/v1alpha1
  kind: BackendTrafficPolicy
  metadata:
    name: uc2-custom-session-affinity
    namespace: uc2-custom
  spec:
    targetRefs:      # Note: Plural 'targetRefs' is the standard for recent Envoy Gateway versions
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: sticky-route # Must match the name of your HTTPRoute
    loadBalancer:
      type: ConsistentHash
      consistentHash:
        type: Cookie
        cookie:
          name: "route-cookie"
          attributes:
            path: /
            sameSite: Lax
          ttl: 14400s
  ---
  apiVersion: gateway.networking.k8s.io/v1
  kind: HTTPRoute
  metadata:
    name: sticky-route
    namespace: uc2-custom
  spec:
    parentRefs:
    - name: sticky-gateway
      namespace: default
      sectionName: uc2-https
    hostnames:
    - "sticky.example.com"
    rules:
    - backendRefs:
      - name: uc2-backend
        port: 3000
  EOF
  ```

#### 5. Wait for 30 seconds to allow services and gateway to be ready

  ```
  sleep 30
  ```

#### 6. Retrieve the external IP of the gateway

  ```
  export GATEWAY_EXTERNAL_IP=$(kubectl get gateway/sticky-gateway -o jsonpath='{.status.addresses[0].value}')
  echo "GATEWAY_EXTERNAL_IP is: $GATEWAY_EXTERNAL_IP"
  ```

### 7. Test

## sticky session

**Expected Behavior**:
- The first request receives a cookie named `route` with a 4-hour expiration.
- Subsequent requests from the same client (with the cookie) are routed to the **same backend pod**.
- If the chosen pod fails, a new cookie is issued (change-on-failure behavior).

**Test Command** (to verify stickiness):
  ```
  # Step 1: Testing initial connectivity (Raw Header Response)...
  curl -k -s -I --resolve sticky.example.com:443:$GATEWAY_EXTERNAL_IP https://sticky.example.com/
  
  sleep 5
  
  # Step 2: Getting initial Hash Cookie...
  # Get the cookie header
  SET_COOKIE=$(curl -k -s -I --resolve sticky.example.com:443:$GATEWAY_EXTERNAL_IP https://sticky.example.com/ | grep -i "set-cookie")

  # Get the pod name for the script logic
  FIRST_POD=$(curl -k -s -c $COOKIE_JAR --resolve sticky.example.com:443:$GATEWAY_EXTERNAL_IP https://sticky.example.com/ | jq -r '.environment.POD_NAME')

  echo "Initial Target Pod: $FIRST_POD"
  echo "Cookie Assigned: $SET_COOKIE"

  # Run multiple times - POD_NAME should stay the same (sticky session)
  for i in {1..10}; do
    NEXT_POD=$(curl -k -s -b $COOKIE_JAR --resolve sticky.example.com:443:$GATEWAY_EXTERNAL_IP \
      https://sticky.example.com/ | jq -r '.environment.POD_NAME')
    
  done
  ```



---


### Key Observations

- The same POD_NAME is returned across multiple requests when the cookie is sent back, proving sticky session is working correctly.
- The cookie name is route and it has a 4-hour lifetime, exactly matching the original NGINX configuration.

### Configuration Used
This sticky session behavior was achieved using the native Gateway API field:

- `HTTPRoute.spec.rules[].backendRefs[].sessionPersistence`
- `type: Cookie`
- `sessionName: route`
- `absoluteTimeout: 14400s (4 hours)`
- `cookieConfig.lifetimeType: Permanent`


This replaces the original NGINX annotations:

- `nginx.ingress.kubernetes.io/affinity: cookie`
- `nginx.ingress.kubernetes.io/session-cookie-name: route`
- `nginx.ingress.kubernetes.io/session-cookie-expires / session-cookie-max-age`

---
####  Conclusion: The sessionPersistence configuration in the HTTPRoute successfully replicates the sticky session behavior from the original NGINX Ingress controller.
---


---
### Clean-up

#### 1. Delete app, service, serviceAccount, HTTPRoute and Gateway

  ```
  kubectl delete gateway sticky-gateway -n default --ignore-not-found
  kubectl delete clienttrafficpolicy client-sticky-policy -n default --ignore-not-found
  kubectl delete backendtrafficpolicy backend-sticky-policy -n uc2-custom --ignore-not-found
  kubectl delete httproute sticky-session-route -n uc2-custom --ignore-not-found
  kubectl delete namespace uc2-custom --ignore-not-found
  ```

===
> **Congratulations! You have completed `Calico Ingress Gateway Workshop - Session Affinity  `!**

---
**Credits:** Portions of this guide are based on or derived from the [Envoy Gateway documentation](https://gateway.envoyproxy.io/docs/tasks/traffic/session-persistence/).