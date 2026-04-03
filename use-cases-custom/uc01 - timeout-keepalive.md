# Calico Ingress Gateway - Long Timeouts + Keep-Alive

### Table of Contents

* [Overview](#overview)
* [High Level Tasks](#high-level-tasks)
* [Diagram](#diagram)
* [Demo](#demo)
* [Clean-up](#clean-up)

---

### Overview

This example demonstrates how to translate advanced NGINX Ingress annotations for **long timeouts**, **keep-alive**, and large request bodies into **Gateway API** resources using Calico Ingress Gateway (based on Envoy).

We deliberately split resources across namespaces to reflect real enterprise patterns:
- Infrastructure (Gateway) lives in the `default` namespace
- Application workload (HTTPRoute, BackendTrafficPolicy, etc.) lives in a dedicated business namespace `uc1-custom`
  

#### Real-World Use Cases

- **Long-running API Requests & File Uploads**: Services handling large payloads (documents, videos, bulk data) require extended timeouts to avoid premature request termination.
- **High-Throughput Applications**: APIs with frequent calls, long-polling, or connection-heavy workloads benefit from aggressive keep-alive to reduce overhead and improve performance.
- **Stateful or Latency-Sensitive Services**: Backends performing heavy computation or maintaining session state need reliable long timeouts and connection reuse for consistent user experience.

In the original NGINX Ingress resource we used the following annotations:

```yaml
annotations:
  keep-alive: "750"
  keep-alive-requests: "1000000"
  upstream-keepalive-requests: "1000000"
  nginx.ingress.kubernetes.io/proxy-body-size: "110m"
  nginx.ingress.kubernetes.io/proxy-connect-timeout: "590"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "590"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "590"
  nginx.ingress.kubernetes.io/proxy-next-upstream-timeout: "590"
```

### High Level Tasks

- Create Namespace `uc1-custom`
- Deploy the backend application (Deployment + Service) in `uc1-custom`
- Create Gateway resource in `default` namespace
- Create ClientTrafficPolicy (in `default`)
- Create HTTPRoute + BackendTrafficPolicy in `uc1-custom`

---


### Diagram
```text
    +-------------------------------------------------------------+
    |                      Kubernetes Cluster                     |
    |                                                             |
    |  +------------------+          +---------------------+      |
    |  |   default NS     |          |  uc1-custom NS      |      |
    |  |                  |          |                     |      |
    |  |  [Gateway]       |<-------->|  [HTTPRoute]        |      |
    |  |  keepalive-      |          |                     |      |
    |  |  timeout-gateway |          |  backendRefs ->     |      |
    |  |                  |          |     [uc1-backend]   |      |
    |  |  ClientTraffic   |          |     Deployment      |      |
    |  |  Policy          |          |     Service         |      |
    |  +------------------+          +---------------------+      |
    |                                                             |  
    |                                                             |
    +-------------------------------------------------------------+
              ↑ HTTP /HTTPS Traffic                             
              │ (with Keep-Alive + Long Timeouts)                
        External Clients 
```
---

**Key Points**:
- The **Gateway** acts as shared infrastructure in the `default` namespace.
- Application-specific routing and workloads are isolated in the `uc1-custom` namespace.


### Demo

#### 1. Generate certificate
  ```
  # Generate the key and cert
  openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
    -subj '/CN=app.example.com/O=MyOrg' \
    -keyout app-example-tls.key -out app-example-tls.crt

  # Create the Kubernetes Secret in the same namespace as the Gateway (default)
  kubectl create secret tls app-example-tls-cert \
    --key=app-example-tls.key \
    --cert=app-example-tls.crt
  ```
#### 2. Create a deployment named `Backend` which we will use to test sticky session / session persistence. The deployment will have 4 replicas.

  ```
  kubectl apply -f - <<EOF
  apiVersion: v1
  kind: Namespace
  metadata:
    name: uc1-custom
  ---
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: uc1-backend
    namespace: uc1-custom
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: uc1-backend
    namespace: uc1-custom
    labels:
      app: uc1-backend
      service: uc1-backend
  spec:
    ports:
      - name: http
        port: 3000
        targetPort: 80
    selector:
      app: uc1-backend
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: uc1-backend
    namespace: uc1-custom
  spec:
    replicas: 4
    selector:
      matchLabels:
        app: uc1-backend
    template:
      metadata:
        labels:
          app: uc1-backend
      spec:
        serviceAccountName: uc1-backend
        containers:
        - name: uc1-backend
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
    name: keepalive-timeout-gateway
    namespace: default
  spec:
    gatewayClassName: tigera-gateway-class
    listeners:
    - name: uc1-http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
    - name: uc1-https
      protocol: HTTPS
      port: 443
      hostname: "app.example.com"
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
kind: ClientTrafficPolicy
metadata:
  name: client-keepalive-policy
  namespace: default
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: keepalive-timeout-gateway
  tcpKeepalive:
    idleTime: 750s
    interval: 60s
    probes: 3
  timeout:
    http:
      idleTimeout: 3600s
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: backend-timeout-policy
  namespace: uc1-custom
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: keepalive-timeout-route

---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: keepalive-timeout-route
  namespace: uc1-custom
spec:
  parentRefs:
  - name: keepalive-timeout-gateway
    namespace: default
  hostnames:
  - "app.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: uc1-backend
      port: 3000
    timeouts:
      request: 3600s
      backendRequest: 590s
  EOF
  ```

#### 5. Wait for 30 seconds to allow services and gateway to be ready

  ```
  sleep 30
  ```

#### 6. Retrieve the external IP of the gateway

  ```
  export GATEWAY_EXTERNAL_IP=$(kubectl get gateway/keepalive-timeout-gateway -o jsonpath='{.status.addresses[0].value}')
  echo "GATEWAY_EXTERNAL_IP is: $GATEWAY_EXTERNAL_IP"
  ```

### 7. Test

### Timeout

- Fast requests complete in < 1 second.

- A 60-second delayed request completes successfully after ~60 seconds (instead of timing out with 504 as it would have with default NGINX settings).


Recommended Demo Script (Clean & Professional)
Copy and paste this as your demo commands:


    echo "=== 1. Fast Request (should be quick) ==="
    
    time curl -v -k --resolve app.example.com:443:$GATEWAY_EXTERNAL_IP \
     https://app.example.com/get 2>/dev/null | jq -r '.environment.POD_NAME'

    sleep 5
    echo -e "\n=== 2. Long Request - 60 second delay (proving backendRequest timeout) ==="
    echo "This should take approximately 60 seconds..."
    
    time curl -v -k --max-time 120 --resolve app.example.com:443:$GATEWAY_EXTERNAL_IP \
    "https://app.example.com/?echo_time=60000" | jq -r '.environment.POD_NAME'



<details>
<summary><code>Expected output:</code></summary>

  ```
$ time curl -s -H "Host: app.example.com" http://$GATEWAY_EXTERNAL_IP/   | jq -r '.environment.POD_NAME'
uc1-backend-8477bff549-9vnng

real	0m0.172s
user	0m0.014s
sys	0m0.019s


$ time curl -v -s --max-time 120   -H "Host: app.example.com"   "http://$GATEWAY_EXTERNAL_IP/?echo_time=60000"   | jq -r '.environment.POD_NAME'
*   Trying 4.246.14.96:80...
* Connected to 4.246.14.96 (4.246.14.96) port 80
* using HTTP/1.x
> GET /?echo_time=60000 HTTP/1.1
> Host: app.example.com
> User-Agent: curl/8.13.0
> Accept: */*
>
* Request completely sent off
< HTTP/1.1 200 OK
< content-type: application/json; charset=utf-8
< content-length: 1393
< etag: W/"571-LhDxcrBvwPg018rDxb/7RL2wlqU"
< date: Mon, 30 Mar 2026 22:59:27 GMT
<
{ [1393 bytes data]
* Connection #0 to host 4.246.14.96 left intact
uc1-backend-8477bff549-shsbt

real	1m0.182s
user	0m0.016s
sys	0m0.024s
  ```
</details>

---

"In the original NGINX Ingress annotation, we had `proxy-read-timeout, proxy-send-timeout`, etc. set to `590 seconds`.

By default, most ingress controllers timeout much faster (often 15-60 seconds). Here I'm asking the backend to artificially delay its response by 60 seconds using `?echo_time=60000`.

***Watch the real time*** — the request takes a full minute, yet we still get 200 OK and the correct pod name. This respects to the `backendRequest: 590s` setting in our HTTPRoute, which replaced the old NGINX proxy timeouts."

---



### Keep Alive

In the original NGINX annotations, you had:

>keep-alive: "750" → Keep-alive timeout of 750 seconds
keep-alive-requests: "1000000" and upstream-keepalive-requests: "1000000" → Reuse the same connection for up to 1 million requests

In your current setup:

>ClientTrafficPolicy sets tcpKeepalive + idleTimeout: 3600s (client → Envoy)
Envoy (by default) aggressively reuses connections to the backend


For this test we generate 200 concurent requests using `HEY`

First, install hey if you don't have it:

    # On Mac
    brew install hey

    # On linux
    sudo snap install hey


Then run this command:

    echo "=== Keep-Alive Stress Test (200 requests, concurrency 20) ==="
    hey -n 200 -c 20 \
      -host "app.example.com" \
      https://$GATEWAY_EXTERNAL_IP/

    echo "=== Keep-Alive Disabled Stress Test (200 requests, concurrency 20) ==="
    hey -n 200 -c 20 -host "app.example.com" --disable-keepalive https://$GATEWAY_EXTERNAL_IP/


<details>
<summary><code>Expected output:</code></summary>

  ```
$ hey -n 200 -c 20 -host "app.example.com" http://$GATEWAY_EXTERNAL_IP/

Summary:
  Total:	0.7475 secs.     < --- Total Time
  Slowest:	0.1761 secs
  Fastest:	0.0607 secs
  Average:	0.0725 secs.     < --- Average Response Time
  Requests/sec:	267.5665     < ---- Request per second

  Total data:	278600 bytes
  Size/request:	1393 bytes

Response time histogram:
  0.061 [1]	|
  0.072 [176]	|■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.084 [3]	|■
  0.095 [0]	|
  0.107 [0]	|
  0.118 [0]	|
  0.130 [1]	|
  0.142 [10]	|■■
  0.153 [5]	|■
  0.165 [2]	|
  0.176 [2]	|


Latency distribution:
  10% in 0.0623 secs
  25% in 0.0631 secs
  50% in 0.0643 secs
  75% in 0.0658 secs
  90% in 0.1286 secs
  95% in 0.1408 secs
  99% in 0.1734 secs

Details (average, fastest, slowest):
  DNS+dialup:	0.0062 secs, 0.0607 secs, 0.1761 secs
  DNS-lookup:	0.0000 secs, 0.0000 secs, 0.0000 secs
  req write:	0.0000 secs, 0.0000 secs, 0.0002 secs
  resp wait:	0.0661 secs, 0.0606 secs, 0.1121 secs
  resp read:	0.0000 secs, 0.0000 secs, 0.0002 secs

Status code distribution:
  [200]	200 responses



meysam-macbook-pro:uc1-ws meysam$
meysam-macbook-pro:uc1-ws meysam$
meysam-macbook-pro:uc1-ws meysam$ hey -n 200 -c 20 -host "app.example.com" --disable-keepalive http://$GATEWAY_EXTERNAL_IP/

Summary:
  Total:	1.3347 secs         < --- Total Time
  Slowest:	0.1798 secs
  Fastest:	0.1232 secs
  Average:	0.1312 secs      < --- Average Response Time
  Requests/sec:	149.8488     < ---- Request per second

  Total data:	278600 bytes
  Size/request:	1393 bytes

Response time histogram:
  0.123 [1]	|
  0.129 [106]	|■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.135 [56]	|■■■■■■■■■■■■■■■■■■■■■
  0.140 [18]	|■■■■■■■
  0.146 [7]	|■■■
  0.152 [1]	|
  0.157 [3]	|■
  0.163 [3]	|■
  0.168 [3]	|■
  0.174 [1]	|
  0.180 [1]	|


Latency distribution:
  10% in 0.1250 secs
  25% in 0.1265 secs
  50% in 0.1285 secs
  75% in 0.1317 secs
  90% in 0.1382 secs
  95% in 0.1538 secs
  99% in 0.1707 secs

Details (average, fastest, slowest):
  DNS+dialup:	0.0622 secs, 0.1232 secs, 0.1798 secs
  DNS-lookup:	0.0000 secs, 0.0000 secs, 0.0000 secs
  req write:	0.0000 secs, 0.0000 secs, 0.0001 secs
  resp wait:	0.0689 secs, 0.0619 secs, 0.1156 secs
  resp read:	0.0001 secs, 0.0000 secs, 0.0009 secs

Status code distribution:
  [200]	200 responses
  ```
</details>

### Keep-Alive Performance Comparison

We sent **200 requests** with **20 concurrent users** to demonstrate the benefit of connection reuse.

| Metric                    | With Keep-Alive                  | Without Keep-Alive (`--disable-keepalive`) | Improvement          |
|---------------------------|----------------------------------|---------------------------------------------|----------------------|
| **Total Time**            | **0.7475 seconds**               | 1.3347 seconds                              | **1.79x faster**     |
| **Requests per second**   | **267.57 req/s**                 | 149.85 req/s                                | **+78.6%**           |
| **Average Response Time** | **0.0725 seconds**               | 0.1312 seconds                              | **1.81x faster**     |
| **DNS + Dialup Time**     | **0.0062 seconds**               | **0.0622 seconds**                          | **~10x lower**       |
| **Slowest Request**       | 0.1761 seconds                   | 0.1798 seconds                              | Similar              |

### Key Observations

- **DNS + Dialup time** is **~10x lower** when keep-alive is enabled. This shows that most requests are reusing existing TCP connections instead of opening new ones for every request.
- Throughput increased by **78.6%** (from 150 → 268 requests/second) just by enabling connection reuse.
- Average latency dropped by nearly **half**.

### Configuration Used

This improvement was achieved by configuring the following in Gateway API:

- **`ClientTrafficPolicy`**:
  - `tcpKeepalive.idleTime: 750s`
  - `http.idleTimeout: 3600s`

This replaces the original NGINX annotations:
- `keep-alive: "750"`
- `keep-alive-requests: "1000000"`
- `upstream-keepalive-requests: "1000000"`

---
### Clean-up

#### 1. Delete app, service, serviceAccount, HTTPRoute and Gateway

  ```
  kubectl delete gateway keepalive-timeout-gateway -n default --ignore-not-found
  kubectl delete clienttrafficpolicy client-keepalive-policy -n default --ignore-not-found
  kubectl delete backendtrafficpolicy backend-timeout-policy -n uc1-custom --ignore-not-found
  kubectl delete httproute keepalive-timeout-route -n uc1-custom --ignore-not-found
  kubectl delete namespace uc1-custom --ignore-not-found
  ```

===
> **Congratulations! You have completed `Calico Ingress Gateway Workshop - Timeout and KeepAlive `!**

---
**Credits:** Portions of this guide are based on or derived from the [Envoy Gateway documentation](https://gateway.envoyproxy.io/docs/tasks/traffic/session-persistence/).