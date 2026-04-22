[← Back to Lessons](../../README.md#lessons)

# Helm and ingress

# Table of contents

- [Helm and ingress](#helm-and-ingress)
- [What we will create](#what-we-will-create)
- [Prerequisites](#prerequisites)
- [Installing Helm](#installing-helm)
- [Installing the ingress-nginx controller with Helm](#installing-the-ingress-nginx-controller-with-helm)
- [The example Helm chart](#the-example-helm-chart)
- [Installing the first nginx release](#installing-the-first-nginx-release)
- [Installing the second nginx release](#installing-the-second-nginx-release)
- [Testing the ingresses](#testing-the-ingresses)
- [Useful Helm commands](#useful-helm-commands)
- [Cleaning up](#cleaning-up)

---

## Helm and ingress

In this lesson, we will do 2 important things:

1. Install the `ingress-nginx` controller from an official Helm chart.
2. Create and install our own small Helm chart for nginx.

We will install our chart twice:

- once for `/nginxa`
- once for `/nginxb`

Each release will:

- create its own `ConfigMap`
- create its own `Deployment`
- create its own `Service`
- create its own `Ingress`

The html content will come from a templated ConfigMap built from values files.

This gives us a simple and practical example of how Helm can turn one chart into multiple similar applications with different configuration.

---

## What we will create

We will use:

- `ingress-nginx-values.yaml`
- a local chart in `simple-nginx-chart/`
- `values-nginxa.yaml`
- `values-nginxb.yaml`

---

## Prerequisites

Before running these examples, make sure:

1. Your Kubernetes cluster is up and working.
2. MetalLB is installed and working from the previous lessons.
3. Your MetalLB pool includes the IP `192.168.50.70`.
4. Your nodes can pull the public image `nginx:1.25`.
5. `curl` is installed on `k8s-master`.

The MetalLB points are somewhat optional, without them, the ingress service will work, it will just have a <pending> external IP.

We will use a fixed LoadBalancer IP for the ingress controller:

```text
192.168.50.70
```

This must be inside the MetalLB pool you configured earlier.

---

## Installing Helm

The official Helm docs provide an install script.

On `k8s-master`, run:

```bash
cd ~
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
```

Check that Helm works:

```bash
helm version
```

Official Helm install docs:

- https://helm.sh/docs/intro/install/

---

## Installing the ingress-nginx controller with Helm

First, go into the lesson directory:

```bash
cd /vagrant/lessons/10-helm-and-ingress
```

Add the official ingress-nginx Helm repository:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

Our `ingress-nginx-values.yaml` configures the controller service as:

- `type: LoadBalancer`
- `loadBalancerIP: 192.168.50.70`

It also explicitly sets node ports.

That means the controller will have:

- a MetalLB-backed LoadBalancer IP
- NodePort access at fixed ports

Install the controller:

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f ingress-nginx-values.yaml
```

Check the controller:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

You should see a controller service with:

- external IP `192.168.50.70`
- node ports `31080` and `31443`

Official ingress-nginx Helm install docs:

- https://kubernetes.github.io/ingress-nginx/deploy/

---

## The example Helm chart

Inside this lesson we created a local Helm chart:

```text
simple-nginx-chart/
```

This chart templates:

- a `ConfigMap`
- a `Deployment`
- a `Service`
- an `Ingress`

The `ConfigMap` builds an `index.html` file from values like:

- `pageTitle`
- `heading`
- `message`

That `index.html` is then mounted into nginx.

We will install this same chart twice with different values files.

That is one of Helm's biggest advantages:

- one chart
- multiple releases
- different configuration for each release

---

## Installing the first nginx release

Install the first release:

```bash
helm upgrade --install nginxa ./simple-nginx-chart -f ./simple-nginx-chart/values.yaml -f values-nginxa.yaml
```

Check what it created:

```bash
helm list
kubectl get all
kubectl get ingress
```

This release will expose:

```text
/nginxa
```

through its own Ingress rule.

The chart also rewrites that path back to `/` before sending the request to nginx, so the static site is served correctly.

---

## Installing the second nginx release

Install the second release:

```bash
helm upgrade --install nginxb ./simple-nginx-chart -f ./simple-nginx-chart/values.yaml -f values-nginxb.yaml
```

Check again:

```bash
helm list
kubectl get all
kubectl get ingress
```

This release will expose:

```text
/nginxb
```

through its own Ingress rule.

Just like the first one, the path is rewritten back to `/` before it reaches nginx.

---

## Testing the ingresses

First, verify the ingress resources:

```bash
kubectl get ingress
kubectl describe ingress nginxa-simple-nginx
kubectl describe ingress nginxb-simple-nginx
```

Now test through the ingress controller LoadBalancer IP:

```bash
curl http://192.168.50.70/nginxa
curl http://192.168.50.70/nginxb
```

You should get different html pages.

You can also test through the NodePort on any node IP:

```bash
curl http://192.168.50.10:31080/nginxa
curl http://192.168.50.10:31080/nginxb
```

or:

```text
http://192.168.50.11:31080/nginxa
http://192.168.50.11:31080/nginxb
```

This works because the ingress-nginx controller itself is exposed by a Service, and then it routes requests internally based on the path rules:

- `/nginxa`
- `/nginxb`

The chart uses an ingress rewrite annotation so that `/nginxa` and `/nginxb` are forwarded to nginx as `/`.

That is important because plain nginx static file serving would otherwise try to find literal paths named `/nginxa` and `/nginxb`.

---

## Useful Helm commands

Render the chart locally without installing it:

```bash
helm template nginxa ./simple-nginx-chart -f values-nginxa.yaml
```

See the values of a release:

```bash
helm get values nginxa
helm get values nginxb
```

See the full rendered manifests of a release:

```bash
helm get manifest nginxa
helm get manifest nginxb
```

Upgrade a release after changing values:

```bash
helm upgrade nginxa ./simple-nginx-chart -f values-nginxa.yaml
```

---

## Cleaning up

To remove the 2 nginx releases:

```bash
helm uninstall nginxa
helm uninstall nginxb
```

You can leave the ingress controller here if you want.

Otherwise, to remove the ingress controller:

```bash
helm uninstall ingress-nginx -n ingress-nginx
```

If you also want to remove the namespace:

```bash
kubectl delete namespace ingress-nginx
```

---

# [11 - Affinities and taints](../11-affinities-and-taints/README.md)
