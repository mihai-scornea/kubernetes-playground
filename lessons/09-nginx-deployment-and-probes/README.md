[← Back to Lessons](../../README.md#lessons)

# Deployment and probes

# Table of contents

- [Deployment and probes](#deployment-and-probes)
- [What we will create](#what-we-will-create)
- [Prerequisites](#prerequisites)
- [The 2 content versions](#the-2-content-versions)
- [The 4 deployment variants](#the-4-deployment-variants)
- [Creating the resources](#creating-the-resources)
- [Why some requests time out without probes](#why-some-requests-time-out-without-probes)
- [Watching the service during updates](#watching-the-service-during-updates)
- [Trying the rolling updates](#trying-the-rolling-updates)
- [Cleaning up](#cleaning-up)

---

## Deployment and probes

In this lesson, we will build a rolling update demo around nginx Deployments.

We will create:

- 2 `ConfigMap` resources with different `index.html` content
- 4 `Deployment` manifests
- 1 `Service` that reaches all matching pods
- 1 watcher script that keeps querying the service and reports what it sees

The goal is to compare Deployments that do not use health probes with Deployments that do.

This makes it much easier to see why readiness probes matter during rolling updates.

---

## What we will create

We will use these files:

- `configmap-a.yaml`
- `configmap-b.yaml`
- `deployment-a-no-probes.yaml`
- `deployment-b-no-probes.yaml`
- `deployment-a-with-probes.yaml`
- `deployment-b-with-probes.yaml`
- `nginx-rolling-service.yaml`
- `watch-service-rolling-stats.sh`

---

## Prerequisites

Before running these examples, make sure:

1. Your Kubernetes cluster is up and working.
2. Your nodes can pull the public image `nginx:1.25`.
3. `kubectl` and `curl` are available on `k8s-master`.

---

## The 2 content versions

The 2 ConfigMaps represent 2 different application versions:

- version A
- version B

Each one contains a different `index.html`.

That way, when we query the Service, we can see which version answered the request.

---

## The 4 deployment variants

We have 4 Deployment manifests:

- `deployment-a-no-probes.yaml`
- `deployment-b-no-probes.yaml`
- `deployment-a-with-probes.yaml`
- `deployment-b-with-probes.yaml`

The first pair has no probes.

The second pair has startup, readiness, and liveness probes.

All 4 manifest files describe different versions of the same Deployment resource:

- `nginx-rolling-demo`

That means we do not run all 4 at the same time as separate Deployments.

Instead, we apply one manifest, then apply another one over it, so that Kubernetes performs a rolling update and creates new ReplicaSets behind the scenes.

All 4 versions:

- use the same Deployment name
- use the same shared app label
- are selected by the same Service
- mount either ConfigMap A or ConfigMap B

To make the difference visible, all containers intentionally wait a short moment before starting nginx.

Without readiness probes, Kubernetes may send traffic to those pods before nginx is actually listening.

With probes enabled, Kubernetes treats startup, readiness, and ongoing health more carefully.

---

## Creating the resources

Go into this lesson directory:

```bash
cd /vagrant/lessons/09-nginx-deployment-and-probes
```

Create the 2 ConfigMaps:

```bash
kubectl apply -f configmap-a.yaml
kubectl apply -f configmap-b.yaml
```

Create the Service:

```bash
kubectl apply -f nginx-rolling-service.yaml
```

For the first experiment, create version A without probes:

```bash
kubectl apply -f deployment-a-no-probes.yaml
```

Inspect what exists:

```bash
kubectl get deployments
kubectl get rs
kubectl get pods -l app=nginx-rolling-demo -o wide
kubectl get svc nginx-rolling-service
```

At this point, the Service reaches the pods from version A.

Later, when we apply another manifest with the same Deployment name but a different pod template, Kubernetes will perform a rolling update.

During that process, the Service can temporarily reach pods from both the old ReplicaSet and the new ReplicaSet.

---

## Why some requests time out without probes

In these manifests, nginx does not start immediately.

We intentionally start the container with a delay:

```bash
sleep 1 && exec nginx -g 'daemon off;'
```

This command is there on purpose for the demo.

Plain nginx usually starts very fast, so in a small lab it can be hard to actually see the difference between having probes and not having them.

The `sleep 1` creates a short startup window where the container process exists, but nginx is not listening yet.

That gives us a realistic situation where traffic can accidentally reach a pod too early if probes are not configured well.

Without a readiness probe, Kubernetes can treat that pod as ready too early.

That means the Service may sometimes send traffic to a pod where nginx is not listening yet.

Those requests can time out.

With readiness probes, Kubernetes waits until the pod actually responds on port 80 before adding it to the Service endpoints.

In the probe-enabled manifests, we also added a startup probe.

That helps Kubernetes understand that the container is still in its startup phase and should be given time to come up cleanly before normal health checking fully takes over.

So in this lesson:

- the `startupProbe` covers the initial startup period
- the `readinessProbe` decides when the pod may receive traffic
- the `livenessProbe` keeps checking that the container is still healthy after startup

In the probe-enabled manifests, we also added a few rollout-smoothing settings:

- `minReadySeconds: 3` so a new pod must stay ready for a few seconds before Kubernetes counts it as truly available
- `preStop: sleep 5` so an old pod gets a short grace period while it is being terminated
- `terminationGracePeriodSeconds: 10` so the container has time to finish that preStop delay cleanly

These settings make the "with probes" rollout more stable and reduce the small timing windows where a request might still get dropped.

That is what we want during rolling updates.

---

## Watching the service during updates

Our Service is a `NodePort` service.

That means it is reachable on any node IP at port `30090`.

For example:

```bash
curl http://192.168.50.10:30090
```

You can also use:

```text
http://192.168.50.11:30090
http://192.168.50.12:30090
```

Then, on `k8s-master`, make the script executable and run it:

```bash
chmod +x watch-service-rolling-stats.sh
./watch-service-rolling-stats.sh
```

If you want to target a different node IP, you can override the default URL:

```bash
SERVICE_URL=http://192.168.50.11:30090 ./watch-service-rolling-stats.sh
```

The script:

- sends requests to `http://192.168.50.10:30090` by default
- uses a default timeout of `1.0` second
- keeps a rolling history of the last `100` queries
- prints a summary every `10` queries
- shows the percentage of version A responses
- shows the percentage of version B responses
- shows the percentage of timeouts
- shows the ReplicaSets and their desired and current pod counts

If everything is working, you will see output blocks that look roughly like:

```text
After 10 queries:
A: 60.00%
B: 40.00%
Timeouts: 0.00%
```

The exact numbers will vary.

If you want to make the watcher stricter or more forgiving, you can override the timeout too:

```bash
TIMEOUT_SECONDS=0.5 ./watch-service-rolling-stats.sh
TIMEOUT_SECONDS=2.0 ./watch-service-rolling-stats.sh
```

---

## Trying the rolling updates

While keeping the script running in a k8s-master terminal, open a second one and go to the lesson's folder there as well:

```bash
cd /vagrant/lessons/09-nginx-deployment-and-probes
```

### Experiment 1: rollout without probes

Start from version A without probes:

```bash
kubectl apply -f deployment-a-no-probes.yaml
kubectl rollout status deployment/nginx-rolling-demo
```

Then roll forward to version B without probes:

```bash
kubectl apply -f deployment-b-no-probes.yaml
```

Watch the rollout:

```bash
kubectl rollout status deployment/nginx-rolling-demo
kubectl get rs
```

Because this version does not use readiness probes, you may see timeout percentages while the new ReplicaSet pods are starting.

You can also roll back to version A without probes:

```bash
kubectl apply -f deployment-a-no-probes.yaml
kubectl rollout status deployment/nginx-rolling-demo
```

### Experiment 2: rollout with probes

Now switch to version A with probes:

```bash
kubectl apply -f deployment-a-with-probes.yaml
kubectl rollout status deployment/nginx-rolling-demo
```

Then roll forward to version B with probes:

```bash
kubectl apply -f deployment-b-with-probes.yaml
```

Watch the rollout:

```bash
kubectl rollout status deployment/nginx-rolling-demo
kubectl get rs
```

You can also move back to version A with probes:

```bash
kubectl apply -f deployment-a-with-probes.yaml
kubectl rollout status deployment/nginx-rolling-demo
```

Here, the timeout percentage should be much lower or disappear entirely, because the readiness probes prevent traffic from going to pods that are not actually serving yet.

This is the main lesson:

- without probes, rolling changes can send traffic to not-yet-ready containers
- with probes, Services only send traffic to containers that have actually become ready

---

## Cleaning up

To remove the resources from this lesson:

```bash
kubectl delete deployment nginx-rolling-demo --ignore-not-found
kubectl delete -f nginx-rolling-service.yaml
kubectl delete -f configmap-a.yaml
kubectl delete -f configmap-b.yaml
```

---

# [10 - Helm and Ingress](../10-helm-and-ingress/README.md)
