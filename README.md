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