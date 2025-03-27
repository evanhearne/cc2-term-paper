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

### Setting up Kuadrant

See [here](https://docs.kuadrant.io/dev/getting-started/) for setting up Kuadrant.

### Apply policies

Custom resource files and policies were created following the [SCP guide](https://docs.kuadrant.io/dev/kuadrant-operator/doc/user-guides/full-walkthrough/secure-protect-connect/) . 

|File|Description|
|----|-----------|
|api.yaml|Deploy custom API image into cluster.|
|api-httproute.yaml|Set up HTTP route for custom API in cluster. |
|gateway-tlspolicy.yaml|Deploy Gateway TLS Policy in cluster. |
|gateway-denyall-auth-policy.yaml|Deploy Auth Policy in cluster. |
|gateway-lowlimit-rate-policy.yaml|Deploy rate limiting policy in cluster. |
|gateway-dnspolicy.yaml|Deploy DNS Policy in cluster. |

CR's and policies can be applied using `kubectl apply -f <file_name>` . 

They are currently being applied following the [SCP guide](https://docs.kuadrant.io/dev/kuadrant-operator/doc/user-guides/full-walkthrough/secure-protect-connect/) . 

### Enforce authentication

#### Set up Kuadrant
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