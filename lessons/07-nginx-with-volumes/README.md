[← Back to Lessons](../../README.md#lessons)

# Nginx with volumes

# Table of contents

- [Nginx with volumes](#nginx-with-volumes)
- [What we will create](#what-we-will-create)
- [Prerequisites](#prerequisites)
- [Preparing the hostPath folders on each node](#preparing-the-hostpath-folders-on-each-node)
- [Creating the hostPath nginx pods](#creating-the-hostpath-nginx-pods)
- [Creating the services](#creating-the-services)
- [Testing the node specific nginx pods](#testing-the-node-specific-nginx-pods)
- [Creating a pod with 2 nginx containers and a ConfigMap](#creating-a-pod-with-2-nginx-containers-and-a-configmap)
- [Testing the multi-container nginx pod](#testing-the-multi-container-nginx-pod)
- [Creating a pod with a shared emptyDir volume](#creating-a-pod-with-a-shared-emptydir-volume)
- [Testing the shared emptyDir volume](#testing-the-shared-emptydir-volume)
- [Cleaning up](#cleaning-up)

---

## Nginx with volumes

In this lesson, we will look at 3 useful Kubernetes storage and configuration concepts:

- `hostPath`
- `emptyDir`
- `ConfigMap`

First, we will create 2 nginx pods that each mount a folder from the host machine.

One pod will run on `k8s-worker-1` and the other on `k8s-worker-2`.

Then, we will create one pod with 2 containers that share an `emptyDir` volume so that we can see how containers inside the same pod can share files.

We will also create one pod with 2 separate nginx containers.

They will listen on different ports, share the same pod IP address, and mount different files from the same ConfigMap so that each container serves different content.

---

## What we will create

We will use these files:

- `worker-1-nginx-pod.yaml`
- `worker-1-nginx-service.yaml`
- `worker-2-nginx-pod.yaml`
- `worker-2-nginx-service.yaml`
- `dual-nginx-configmap.yaml`
- `dual-nginx-pod.yaml`
- `dual-nginx-service.yaml`
- `shared-emptydir-pod.yaml`

We will also use these example content folders:

- `volumes-example-1`
- `volumes-example-2`

---

## Prerequisites

Before running these examples, make sure:

1. Your Kubernetes cluster is up and working.
2. The `tester-pod` from the previous lessons exists and is running.

In this lesson, we will use the public `nginx:1.25` image for the nginx pods, so this example does not depend on the custom nginx image from Nexus.

---

## Preparing the hostPath folders on each node

Our nginx pods will mount this host path:

```text
/home/vagrant/volumes-example
```

Because `hostPath` uses a directory from the node's own filesystem, we need to prepare the correct content on each worker node.

In this lesson folder, we created 2 example directories:

- `volumes-example-1`
- `volumes-example-2`

Each one contains its own `index.html` that says which node it belongs to.

### On k8s-worker-1

Connect to `k8s-worker-1` and run:

```bash
rm -rf /home/vagrant/volumes-example
cp -r /vagrant/lessons/07-nginx-with-volumes/volumes-example-1 /home/vagrant/volumes-example
```

### On k8s-worker-2

Connect to `k8s-worker-2` and run:

```bash
rm -rf /home/vagrant/volumes-example
cp -r /vagrant/lessons/07-nginx-with-volumes/volumes-example-2 /home/vagrant/volumes-example
```

This is important because even though both pods use the same host path:

```text
/home/vagrant/volumes-example
```

they run on different nodes, so each node needs its own local directory content.

---

## Creating the hostPath nginx pods

Go into this lesson directory on k8s-master:

```bash
cd /vagrant/lessons/07-nginx-with-volumes
```

Create the pod pinned to `k8s-worker-1`:

```bash
kubectl apply -f worker-1-nginx-pod.yaml
```

Create the pod pinned to `k8s-worker-2`:

```bash
kubectl apply -f worker-2-nginx-pod.yaml
```

Check that both pods are running on the expected nodes:

```bash
kubectl get pods -o wide
```

You should see:

- `worker-1-nginx` on `k8s-worker-1`
- `worker-2-nginx` on `k8s-worker-2`

These pods mount the host folder into:

```text
/usr/share/nginx/html
```

That means nginx will directly serve the `index.html` file coming from the node's filesystem.

---

## Creating the services

Create the service for the first nginx pod:

```bash
kubectl apply -f worker-1-nginx-service.yaml
```

Create the service for the second nginx pod:

```bash
kubectl apply -f worker-2-nginx-service.yaml
```

Check the services:

```bash
kubectl get svc
```

You should see:

- `worker-1-nginx-service`
- `worker-2-nginx-service`

Each service points only to its matching pod through labels.

---

## Testing the node specific nginx pods

We can test them from inside the cluster using `tester-pod`.

Open a shell in `tester-pod`:

```bash
kubectl exec -it tester-pod -- bash
```

Then curl the first service:

```bash
curl http://worker-1-nginx-service
```

You should get the HTML page that says it is from `k8s-worker-1`.

Now curl the second service:

```bash
curl http://worker-2-nginx-service
```

You should get the HTML page that says it is from `k8s-worker-2`.

When you are done:

```bash
exit
```

This demonstrates that:

- both pods are serving different content
- the content comes from the local filesystem of each node
- Kubernetes services route traffic to the correct pod

One important thing to understand about `hostPath` is that it depends on the node.

If a pod gets recreated on a different node, it will see that other node's local filesystem instead.

That is one reason why `hostPath` is useful for experiments and special cases, but not usually the main solution for portable application data.

---

## Creating a pod with 2 nginx containers and a ConfigMap

Now we will create a different kind of example.

This pod will contain 2 nginx containers:

- `nginx-one`
- `nginx-two`

They will both run inside the same pod, which means they will share:

- the same pod IP address
- the same network namespace

Because they share the same network namespace, they can not both listen on port `80`.

So we will configure them like this:

- `nginx-one` listens on port `8081`
- `nginx-two` listens on port `8082`

We will also introduce a ConfigMap.

The ConfigMap contains:

- one html file for the first container
- one html file for the second container
- one nginx config file for the first container
- one nginx config file for the second container

Each container mounts different files from that same ConfigMap using `subPath`.

Create the ConfigMap:

```bash
kubectl apply -f dual-nginx-configmap.yaml
```

Create the pod:

```bash
kubectl apply -f dual-nginx-pod.yaml
```

Create the service:

```bash
kubectl apply -f dual-nginx-service.yaml
```

Check that the pod is running:

```bash
kubectl get pods -o wide
```

You should see:

- `dual-nginx-pod`

Inspect the service:

```bash
kubectl get svc dual-nginx-service
kubectl describe svc dual-nginx-service
```

This service exposes both container ports through one Service resource.

---

## Testing the multi-container nginx pod

We can test this from inside `tester-pod`.

Open a shell:

```bash
kubectl exec -it tester-pod -- bash
```

Then curl the first port:

```bash
curl http://dual-nginx-service:8081
```

You should get the page served by `nginx-one`.

Now curl the second port:

```bash
curl http://dual-nginx-service:8082
```

You should get the page served by `nginx-two`.

When you are done:

```bash
exit
```

This example shows a few very important ideas:

- one pod can contain multiple containers
- all containers in the same pod share one IP address
- they must listen on different ports if they are both serving network traffic
- one ConfigMap can hold multiple files
- different containers can mount different files from the same ConfigMap

If you want to inspect the files mounted in each container, you can run:

```bash
kubectl exec dual-nginx-pod -c nginx-one -- cat /usr/share/nginx/html/index.html
kubectl exec dual-nginx-pod -c nginx-two -- cat /usr/share/nginx/html/index.html
```

You can also inspect the nginx server config used by each container:

```bash
kubectl exec dual-nginx-pod -c nginx-one -- cat /etc/nginx/conf.d/default.conf
kubectl exec dual-nginx-pod -c nginx-two -- cat /etc/nginx/conf.d/default.conf
```

---

## Creating a pod with a shared emptyDir volume

Now create the pod with 2 containers sharing an `emptyDir` volume.

Exit the testing pod and then, on k8s-master:

```bash
kubectl apply -f shared-emptydir-pod.yaml
```

Check that it is running:

```bash
kubectl get pods
```

You should see:

- `shared-emptydir-pod`

This pod has:

- a container named `writer`
- a container named `reader`
- an `emptyDir` volume mounted by both

An `emptyDir` volume is created when the pod starts and exists as long as that pod exists.

It is empty at the beginning, which is where the name comes from.

Both containers in the pod can mount it and read or write the same files.

---

## Testing the shared emptyDir volume

Create a file from the `writer` container:

```bash
kubectl exec shared-emptydir-pod -c writer -- sh -c 'echo "Hello from the writer container" > /shared/message.txt'
```

Now read that same file from the `reader` container:

```bash
kubectl exec shared-emptydir-pod -c reader -- cat /shared/message.txt
```

You should see:

```text
Hello from the writer container
```

This proves that both containers mount the same shared volume.

We can also inspect the directory from each side.

For example, list files from the writer container:

```bash
kubectl exec shared-emptydir-pod -c writer -- ls -l /shared
```

and from the reader container:

```bash
kubectl exec shared-emptydir-pod -c reader -- ls -l /shared
```

Both containers should see the same file.

---

## Cleaning up

To remove all resources from this lesson:

```bash
kubectl delete -f shared-emptydir-pod.yaml
kubectl delete -f dual-nginx-service.yaml
kubectl delete -f dual-nginx-pod.yaml
kubectl delete -f dual-nginx-configmap.yaml
kubectl delete -f worker-2-nginx-service.yaml
kubectl delete -f worker-1-nginx-service.yaml
kubectl delete -f worker-2-nginx-pod.yaml
kubectl delete -f worker-1-nginx-pod.yaml
```

We will keep the folders on the worker nodes unless we explicitly remove them.

---

# [08 - ReplicaSet with ConfigMap and Secret](../08-nginx-replicaset-with-configmap-and-secret/README.md)
