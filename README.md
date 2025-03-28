# cc2-term-paper
This is a repository for my Cloud Computing 2 Term Paper, focusing on Kuadrant.


## What is Kuadrant ?

![Kuadrant Logo](https://github.com/Kuadrant/docs.kuadrant.io/blob/main/docs/assets/images/logo.png?raw=true)

Kuadrant is an open-source Kubernetes native solution for API management. It allows developers and platform engineers to manage their application’s connectivity through DNS, TLS, Rate Limiting and Auth policies. 

In my Cloud Computing 2 Term Paper, I aim to explore how developers can use Kuadrant's policies to manage their APIs. 

## Why Kuadrant ? 

+ Policies are integral to Kuadrant’s management of APIs. 

+ Policies are managed through custom resource definitions attached to a cluster.
Gateway API allows for policy attachment.
    + Istio based gateway allows for connectivity. 

+ Operators bring together these components - DNS, TLS, Rate Limiting, and Authorization. 
    + This allows easy management of components.

+ Observability is an optional component which allows for monitoring and analyzing the performance of an application. 
    + Possible through Grafana and Prometheus.  

## How will Kuadrant be implemented ? 

The practical implementation of Kuadrant needs to demonstrate Kuadrant’s four main features - DNS, TLS, Rate Limiting and Authorization. Additionally, Observability into these features will be needed to prove their functionality.

+ Containerised web application required for Kubernetes cluster.
+ Custom DNS, TLS, Rate-Limiting and Authorization policies required.
+ AWS Route53 HostedZones and local kind cluster used for custom DNS policy.
+ TLS, Rate-Limiting and Authorization policies in a local kind cluster.
+ Importing of App Developer Dashboard to monitor API management required.


## Simple API

A simple API has been made which performs a GET and POST request. It can be made containerizable too via Podman/Docker. 

### How to run API.

Make sure you have Go installed on your machine. Then run

```bash
go mod tidy
go run main.go
```

The GET endpoint is [localhost:8080/ping](localhost:8080/ping) and the POST endpoint is [localhost:8080/echo](localhost:8080/echo) . 

The GET endpoint returns `{"message":"pong"}` and the POST endpoint returns the JSON request as a response e.g. `{"message":"Hello, Go API!"}` . 

### How to containerise the API

Make sure you have Podman or Docker installed on your machine, then run

```bash
podman build -t cc2-term-paper-api . 
podman run -d -p 8080:8080 cc2-term-paper-api
```

See [above](#how-to-run-api) for API usage . 

## Kuadrant

### Policies

Custom resource files and policies were created following the [SCP guide](https://docs.kuadrant.io/dev/kuadrant-operator/doc/user-guides/full-walkthrough/secure-protect-connect/) and other guides listed below . 

|File|Description|
|----|-----------|
|api.yaml|Deploy custom API image into cluster.|
|api-httproute.yaml|Set up HTTP route for custom API in cluster. |
|gateway-auth-policy.yaml|AuthPolicy for securing an external gateway with API Keys.|
|kuadrant-api-key.yaml|API Keys stored as secrets in the cluster - for use with auth policies.|
|ingress-gateway.yaml|An ingress gateway CR.|
|tls-httproute.yaml|Custom HTTP route for API in TLSPolicy setup.|
|rlp-httproute.yaml|Custom HTTP route for API in RateLimitPolicy setup.|

CR's and policies can be applied using `kubectl apply -f <file_name>` followed by `-n <namespace>` for a chosen namespace to deploy into. 

### A note on resource availability within your container runtime.

Make sure you have at least 6GB+ of memory allocated in your container runtime. This can be done within your container runtime configuration. Read the docs for your container runtime to do so.

### Setting up Kuadrant

See [here](https://docs.kuadrant.io/dev/getting-started/) for more info on setting up Kuadrant.

```bash
sudo cloud-provider-kind &
kind create cluster
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
helm repo add jetstack https://charts.jetstack.io --force-update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.15.3 \
  --set crds.enabled=true
helm install sail-operator \
		--create-namespace \
		--namespace istio-system \
		--wait \
		--timeout=300s \
		https://github.com/istio-ecosystem/sail-operator/releases/download/0.1.0/sail-operator-0.1.0.tgz

kubectl apply -f -<<EOF
apiVersion: sailoperator.io/v1alpha1
kind: Istio
metadata:
  name: default
spec:
  # Supported values for sail-operator v0.1.0 are [v1.22.4,v1.23.0]
  version: v1.23.0
  namespace: istio-system
  # Disable autoscaling to reduce dev resources
  values:
    pilot:
      autoscaleEnabled: false
EOF
helm repo add kuadrant https://kuadrant.io/helm-charts/ --force-update
helm install \
 kuadrant-operator kuadrant/kuadrant-operator \
 --create-namespace \
 --namespace kuadrant-system
kubectl apply -f - <<EOF
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
EOF
until kubectl wait --for=condition=Ready kuadrant/kuadrant -n kuadrant-system --timeout=300s; do
    echo "Waiting for Kuadrant to be ready..."
    sleep 10
done
```

### Observability

By setting up observability first, we will have metrics to show for all our policies and API testing.

Clone [kuadrant-operator](https://github.com/Kuadrant/kuadrant-operator/tree/main) and cd into the root directory of repository . Run the commands listed [here](https://github.com/Kuadrant/kuadrant-operator/tree/main/config/observability#deploying-the-observabilty-stack) to deploy the observability stack, remembering that we have an istio gateway. 

Then expose Grafana using `kubectl -n monitoring port-forward service/grafana 3000:3000` . The username and password is `admin` . 

After this, you can head back to cc2-term-paper repo for the following documentation.

### Enforce authentication
This [guide](https://docs.kuadrant.io/dev/kuadrant-operator/doc/user-guides/auth/auth-for-app-devs-and-platform-engineers/) was followed with some modifications for the following:

#### Deploy API + test connection
```bash
export KUADRANT_GATEWAY_NS=api-gateway
export KUADRANT_GATEWAY_NAME=external
export KUADRANT_DEVELOPER_NS=cc2-term-paper-api
kubectl create ns ${KUADRANT_GATEWAY_NS}
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${KUADRANT_GATEWAY_NAME}
  namespace: ${KUADRANT_GATEWAY_NS}
  labels:
    kuadrant.io/gateway: "true"
spec:
  gatewayClassName: istio
  listeners:

    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
EOF
kubectl get gateway ${KUADRANT_GATEWAY_NAME} -n ${KUADRANT_GATEWAY_NS} -o=jsonpath='{.status.conditions[?(@.type=="Accepted")].message}{"\n"}{.status.conditions[?(@.type=="Programmed")].message}{"\n"}'
kubectl create ns ${KUADRANT_DEVELOPER_NS}
kubectl apply -f api.yaml -n ${KUADRANT_DEVELOPER_NS}
kubectl apply -f api-httproute.yaml 
```
This step is required to expose the gateway on macOS systems as Docker based IPs do not expose correctly without [docker-mac-net-connect](https://github.com/chipmk/docker-mac-net-connect) . 

If [docker-mac-net-connect](https://github.com/chipmk/docker-mac-net-connect) is set up correctly, using the load-balancer IP followed by the exposed port should work, though this was not tested during setup. 
```bash
kubectl port-forward -n api-gateway svc/external-istio 8081:80 &
```
```bash
curl -H 'Host: api.evanhearnesetu.com' http://localhost:8081/ping -i
```

#### Apply basic auth policy + API Keys
```bash
kubectl apply -f gateway-auth-policy.yaml
kubectl -n kuadrant-system apply -f kuadrant-api-key.yaml
```

#### Attempt to access endpoint with no key
```bash
curl -H 'Host: api.evanhearnesetu.com' http://localhost:8081/ping -i
```

#### Attempt to access endpoint with key
```bash
curl -H 'Host: api.evanhearnesetu.com' -H 'Authorization: APIKEY iamaregularuser' http://localhost:8081/ping -i
```

### Configuring TLS

This [guide](https://docs.kuadrant.io/dev/kuadrant-operator/doc/user-guides/tls/gateway-tls/#verify-tls-works-by-sending-requests) was used and modified for my use case.

- Set up Kuadrant as before, then:

#### Create new namespace for gateway
```bash
kubectl create namespace my-gateways
```

#### Create gateway
```bash
kubectl -n my-gateways apply -f ingress-gateway.yaml
```

#### Configure TLS with issuer + TLS Policy

```bash
kubectl apply -n my-gateways -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF
```
```bash
kubectl get issuer selfsigned-issuer -n my-gateways
```
```bash
kubectl apply -n my-gateways -f - <<EOF
apiVersion: kuadrant.io/v1
kind: TLSPolicy
metadata:
  name: prod-web
spec:
  targetRef:
    name: prod-web
    group: gateway.networking.k8s.io
    kind: Gateway
  issuerRef:
    group: cert-manager.io
    kind: Issuer
    name: selfsigned-issuer
EOF
```
```bash
kubectl get tlspolicy -o wide -n my-gateways
```
```bash
kubectl get certificates -n my-gateways
```
```bash
kubectl get secrets -n my-gateways --field-selector="type=kubernetes.io/tls"
```

#### Deploy API
```bash
kubectl -n my-gateways apply -f api.yaml
kubectl -n my-gateways wait --for=condition=Available deployments api --timeout=60s
kubectl -n my-gateways apply -f tls-httproute.yaml
```

#### Test TLS Connection
```bash
kubectl -n my-gateways port-forward svc/prod-web-istio 8443:443
curl -vk https://api.api.local:8443/ping --resolve "api.api.local:8443:127.0.0.1"
```

### Enforce rate limiting

This [guide](https://docs.kuadrant.io/dev/kuadrant-operator/doc/user-guides/ratelimiting/gateway-rl-for-cluster-operators/) was used to set up rate limiting. 

- Set up Kuadrant as before, then:

#### Deploy API

```bash
kubectl apply -f api.yaml
```

#### Create the ingress gateways

```bash
kubectl create namespace gateway-system
kubectl -n gateway-system apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: external
  annotations:
    kuadrant.io/namespace: kuadrant-system
    networking.istio.io/service-type: ClusterIP
spec:
  gatewayClassName: istio
  listeners:

  - name: external
    port: 80
    protocol: HTTP
    hostname: '*.io'
    allowedRoutes:
      namespaces:
        from: All
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: internal
  annotations:
    kuadrant.io/namespace: kuadrant-system
    networking.istio.io/service-type: ClusterIP
spec:
  gatewayClassName: istio
  listeners:
  - name: local
    port: 80
    protocol: HTTP
    hostname: '*.local'
    allowedRoutes:
      namespaces:
        from: All
EOF
```

#### Create Rate Limit Policy

```bash
kubectl apply -n gateway-system -f - <<EOF
apiVersion: kuadrant.io/v1
kind: RateLimitPolicy
metadata:
  name: gw-rlp
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: external
  limits:
    "global":
      rates:

      - limit: 5
        window: 10s
EOF
```

#### Add HTTPRoute
```bash
kubectl apply -f rlp-httproute.yaml
```

#### Verify rate limiting in place
##### Expose services
```bash
kubectl port-forward -n gateway-system service/external-istio 9081:80 >/dev/null 2>&1 &
kubectl port-forward -n gateway-system service/internal-istio 9082:80 >/dev/null 2>&1 &
```

##### Up to 5 successful requests via external gateway
```bash
while :; do curl --write-out '%{http_code}\n' --silent --output /dev/null -H 'Host: api.api.io' http://localhost:9081/ping | grep -E --color "\b(429)\b|$"; sleep 1; done
```

##### Unlimited requests via internal gateway
```bash
while :; do curl --write-out '%{http_code}\n' --silent --output /dev/null -H 'Host: api.api.local' http://localhost:9082/ping | grep -E --color "\b(429)\b|$"; sleep 1; done
```