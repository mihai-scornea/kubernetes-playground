[← Back to Lessons](../../README.md#lessons)

# Nginx with services

# Table of contents

- [Nginx with services](#nginx-with-services)
- [What we will create](#what-we-will-create)
- [Prerequisites](#prerequisites)
- [The pod and service files](#the-pod-and-service-files)
- [Creating the nginx pod](#creating-the-nginx-pod)
- [Creating a ClusterIP service](#creating-a-clusterip-service)
- [Creating a NodePort service](#creating-a-nodeport-service)
- [Creating a LoadBalancer service](#creating-a-loadbalancer-service)
- [Installing and configuring MetalLB](#installing-and-configuring-metallb)
- [Testing the services](#testing-the-services)
- [Cleaning up](#cleaning-up)

---

## Nginx with services

In this lesson, we will create one nginx pod and expose it in 3 different ways:

- A `ClusterIP` service
- A `NodePort` service
- A `LoadBalancer` service

This will help us understand the main service types and how traffic reaches pods in Kubernetes.

---

## What we will create

We will use these files:

- `nginx-pod.yaml`
- `nginx-clusterip-service.yaml`
- `nginx-nodeport-service.yaml`
- `nginx-loadbalancer-service.yaml`
- `metallb-ipaddresspool.yaml`
- `metallb-l2advertisement.yaml`

---

## Prerequisites

Before running these examples, make sure:

1. Your Kubernetes cluster is up and working.
2. Your nodes can pull the public image `nginx:1.25`.
3. The `tester-pod` from the previous lesson exists and is running.

In this lesson, we will use the official nginx image:

```text
nginx:1.25
```

Your note about the nodes being on the same network helps a lot here.

That means MetalLB can work well in Layer 2 mode, where one node answers ARP requests for the external LoadBalancer IP.

---

## The pod and service files

The pod is called `custom-nginx-service`.

All 3 services select it using the same label:

```yaml
app: custom-nginx-service
```

This is important because a Service does not connect to a pod by name.

It connects to pods through label selectors.

---

## Creating the nginx pod

Go into this lesson directory:

```bash
cd /vagrant/lessons/06-nginx-with-services
```

Create the pod first:

```bash
kubectl apply -f nginx-pod.yaml
```

Check that it is running:

```bash
kubectl get pods -o wide
```

You should see:

- `custom-nginx-service`

---

## Creating a ClusterIP service

Now create the ClusterIP service:

```bash
kubectl apply -f nginx-clusterip-service.yaml
```

A `ClusterIP` service is only reachable from inside the cluster.

It gets an internal virtual IP and forwards traffic to matching pods.

This is the default service type in Kubernetes.

To inspect it:

```bash
kubectl get svc nginx-clusterip-service
kubectl describe svc nginx-clusterip-service
```

To test it, we will use the `tester-pod` from the previous lesson.

First, get the ClusterIP assigned to the service:

```bash
kubectl get svc nginx-clusterip-service
```

You will see a `CLUSTER-IP` in the output, something like:

```text
10.100.123.45
```

Now open a shell inside `tester-pod`:

```bash
kubectl exec -it tester-pod -- bash
```

Inside that pod, curl the service IP directly:

```bash
curl http://10.100.123.45
```

Of course, replace `10.100.123.45` with the actual ClusterIP from your cluster.

Then curl the service by hostname:

```bash
curl http://nginx-clusterip-service
```

Both commands should return the same nginx page.

The reason the hostname works is that Kubernetes runs DNS for the cluster through CoreDNS.

CoreDNS watches Kubernetes services and pods and creates DNS records for them.

So when `tester-pod` tries to resolve `nginx-clusterip-service`, CoreDNS answers with the IP of that service.

That means service names become a very convenient way for pods to talk to each other without hardcoding IP addresses.

When you are done:

```bash
exit
```

---

## Creating a NodePort service

Now create the NodePort service:

```bash
kubectl apply -f nginx-nodeport-service.yaml
```

A `NodePort` service opens the same port on every node in the cluster.

In our example, we use node port `30080`.

This means the service can be reached on any node IP at:

```text
http://NODE_IP:30080
```

For example:

```text
http://192.168.50.10:30080
http://192.168.50.11:30080
http://192.168.50.12:30080
```

To inspect it:

```bash
kubectl get svc nginx-nodeport-service
kubectl describe svc nginx-nodeport-service
```

---

## Creating a LoadBalancer service

Now create the LoadBalancer service:

```bash
kubectl apply -f nginx-loadbalancer-service.yaml
```

Kubernetes services can be of the type `LoadBalancer`.

A LoadBalancer is usually found where our cluster collaborates with a cloud provider like AWS, Azure, GCP, OpenStack and so on.

The cloud provider can have some sort of network element listening on an external IP address.

A `LoadBalancer` service can hook into that integration so that traffic received on that external IP is forwarded to the service.

Because we do not have a cloud provider in this project, we will use MetalLB to simulate this behavior on our own network.

In our service file, we explicitly request this IP:

```text
192.168.50.60
```

This is inside the range:

```text
192.168.50.50 - 192.168.50.100
```

That range will be managed by MetalLB.

To inspect the service:

```bash
kubectl get svc nginx-loadbalancer-service
kubectl describe svc nginx-loadbalancer-service
```

If MetalLB is configured correctly, the service should receive the external IP `192.168.50.60`.

But right now, we do not have MetalLB so the loadbalancer IP will just be pending.

---

## Installing and configuring MetalLB

MetalLB does not work just by installing its controller.

It also needs configuration that tells it:

- Which IP addresses it is allowed to hand out
- How those IPs should be announced on the network

Install MetalLB:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml
```

Wait for its pods to be running and ready:

```bash
kubectl get pods -n metallb-system
```

Then create the IP pool:

```bash
kubectl apply -f metallb-ipaddresspool.yaml
```

Our adjusted `IPAddressPool` only allows IPs in this range:

```text
192.168.50.50-192.168.50.100
```

This is the exact range you asked for.

After that, create the Layer 2 advertisement:

```bash
kubectl apply -f metallb-l2advertisement.yaml
```

Why do we need the `L2Advertisement`?

Because according to the MetalLB configuration model, assigning IPs is one step and announcing them is another.

The `IPAddressPool` tells MetalLB what IPs it may use, while the `L2Advertisement` tells MetalLB to actually advertise those IPs on the local network through Layer 2.

This is the right approach for our lab because the nodes are on the same network and can already reach each other.

You can inspect the MetalLB resources with:

```bash
kubectl get ipaddresspools -n metallb-system
kubectl get l2advertisements -n metallb-system
kubectl describe ipaddresspool first-pool -n metallb-system
kubectl describe l2advertisement example -n metallb-system
```

If the LoadBalancer service stays in `pending`, this usually means one of these things:

- MetalLB is not fully running yet
- The `IPAddressPool` was not created
- The `L2Advertisement` was not created
- The requested `loadBalancerIP` is outside the configured pool

MetalLB configuration reference:

- https://metallb.io/configuration/
- https://metallb.io/concepts/layer2/

---

## Testing the services

List all services:

```bash
kubectl get svc
```

You should see:

- `nginx-clusterip-service`
- `nginx-nodeport-service`
- `nginx-loadbalancer-service`

You can also see the pod and service endpoints:

```bash
kubectl get pods -o wide
kubectl get endpoints
```

### Testing the ClusterIP service

Because ClusterIP is internal only, the easiest way to test it is from a pod inside the cluster.

For example, using the `tester-pod` from the previous lesson:

```bash
kubectl exec -it tester-pod -- bash
curl http://nginx-clusterip-service
exit
```

### Testing the NodePort service

From your host network, you can access:

```text
http://192.168.50.10:30080
```

or any other node IP on port `30080`.

### Testing the LoadBalancer service

After MetalLB assigns the external IP, you can access:

```text
http://192.168.50.60
```

If the Layer 2 announcement is working correctly, the network should route that IP to one of your cluster nodes, and Kubernetes will forward the traffic to the nginx pod.

---

## Cleaning up

To remove the pod and the 3 services:

```bash
kubectl delete -f nginx-loadbalancer-service.yaml
kubectl delete -f nginx-nodeport-service.yaml
kubectl delete -f nginx-clusterip-service.yaml
kubectl delete -f nginx-pod.yaml
```

If you also want to remove the MetalLB and its configuration created in this lesson:

```bash
kubectl delete -f metallb-l2advertisement.yaml
kubectl delete -f metallb-ipaddresspool.yaml
kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml
```

You will usually want to keep MetalLB installed for future experiments.

---

# [07 - Nginx with Volumes](../07-nginx-with-volumes/README.md)
