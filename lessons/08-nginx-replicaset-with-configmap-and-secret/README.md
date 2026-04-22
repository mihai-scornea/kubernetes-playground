[← Back to Lessons](../../README.md#lessons)

# ReplicaSet with ConfigMap and Secret

# Table of contents

- [ReplicaSet with ConfigMap and Secret](#replicaset-with-configmap-and-secret)
- [What we will create](#what-we-will-create)
- [Prerequisites](#prerequisites)
- [Creating the ConfigMap](#creating-the-configmap)
- [Creating the Secret](#creating-the-secret)
- [Creating the ReplicaSet](#creating-the-replicaset)
- [Creating the Service](#creating-the-service)
- [Creating the DaemonSet](#creating-the-daemonset)
- [Creating the DaemonSet Service](#creating-the-daemonset-service)
- [Testing the nginx content](#testing-the-nginx-content)
- [Scaling the ReplicaSet up and down](#scaling-the-replicaset-up-and-down)
- [Updating the ConfigMap and restarting the replicas](#updating-the-configmap-and-restarting-the-replicas)
- [Inspecting the Secret inside a pod](#inspecting-the-secret-inside-a-pod)
- [ConfigMaps vs Secrets](#configmaps-vs-secrets)
- [Cleaning up](#cleaning-up)

---

## ReplicaSet with ConfigMap and Secret

In this lesson, we will create an nginx ReplicaSet and configure it with:

- a `ConfigMap`
- a `Secret`

We will also create a separate nginx `DaemonSet` with its own Service so we can compare a workload that runs one pod per node.

The `ConfigMap` will provide the `index.html` file that all nginx replicas will serve.

The `Secret` will show how sensitive data can be injected into pods in a way that is very similar to a ConfigMap.

This is a nice step forward from plain pods because we are now starting to separate:

- the container image
- the runtime configuration
- the secret runtime data

---

## What we will create

We will use these files:

- `nginx-configmap.yaml`
- `nginx-secret.yaml`
- `nginx-replicaset.yaml`
- `nginx-service.yaml`
- `nginx-daemonset.yaml`
- `nginx-daemonset-service.yaml`

---

## Prerequisites

Before running these examples, make sure:

1. Your Kubernetes cluster is up and working.
2. The `tester-pod` from the previous lessons exists and is running.
3. Your nodes can pull the public image `nginx:1.25`.

---

## Creating the ConfigMap

The ConfigMap contains the html file that all nginx replicas will use.

Create it with:

```bash
cd /vagrant/lessons/08-nginx-replicaset-with-configmap-and-secret
kubectl apply -f nginx-configmap.yaml
```

You can inspect it with:

```bash
kubectl get configmap nginx-index-config
kubectl describe configmap nginx-index-config
```

This ConfigMap stores a file called `index.html`.

We will mount that file into the nginx document root so that every replica serves the same page.

---

## Creating the Secret

Now create the Secret:

```bash
kubectl apply -f nginx-secret.yaml
```

Inspect it with:

```bash
kubectl get secret nginx-demo-secret
kubectl describe secret nginx-demo-secret
```

This Secret contains one key called:

```text
secret-message
```

We will use this Secret in 2 ways:

- as an environment variable inside the pod
- as a mounted file inside the pod

This helps show that Secrets can be consumed in ways very similar to ConfigMaps.

---

## Creating the ReplicaSet

Now create the ReplicaSet:

```bash
kubectl apply -f nginx-replicaset.yaml
```

Check what was created:

```bash
kubectl get rs
kubectl get pods -l app=nginx-rs-demo -o wide
```

You should see a ReplicaSet named:

- `nginx-rs-demo`

and multiple pods created from it.

In this example, the ReplicaSet keeps `3` nginx pods running.

All of them:

- use the official `nginx:1.25` image
- mount the same `index.html` from the ConfigMap
- get the same Secret as an environment variable
- mount the same Secret as a file volume

If you delete one pod manually, the ReplicaSet will notice and create a replacement.

For example:

```bash
kubectl get pods -l app=nginx-rs-demo
kubectl delete pod <one-of-the-pod-names>
kubectl get pods -l app=nginx-rs-demo
```

You will see that a new pod appears so that the desired replica count stays at `3`.

---

## Creating the Service

Now create a Service for the ReplicaSet:

```bash
kubectl apply -f nginx-service.yaml
```

Inspect it with:

```bash
kubectl get svc nginx-rs-service
kubectl describe svc nginx-rs-service
```

This Service selects all pods with the label:

```yaml
app: nginx-rs-demo
```

That means the Service can forward traffic to all replicas managed by the ReplicaSet.

Using a Service is much more practical than targeting pod IPs directly, because pod IPs can change when pods are recreated.

---

## Creating the DaemonSet

Now create the DaemonSet:

```bash
kubectl apply -f nginx-daemonset.yaml
```

Inspect it with:

```bash
kubectl get daemonset nginx-daemon-demo
kubectl get pods -l app=nginx-daemon-demo -o wide
```

A DaemonSet works differently from a ReplicaSet.

Instead of keeping a chosen number of replicas, it makes sure one matching pod runs on each eligible node.

That means if your cluster has:

- `2` nodes, you should see `2` DaemonSet pods
- `3` nodes, you should see `3` DaemonSet pods

This is useful for workloads that should exist everywhere, such as:

- log collectors
- monitoring agents
- node-level networking components

In our case, we are just using a default nginx pod so the behavior is easy to observe.

---

## Creating the DaemonSet Service

Now create a Service for the DaemonSet:

```bash
kubectl apply -f nginx-daemonset-service.yaml
```

Inspect it with:

```bash
kubectl get svc nginx-daemon-service
kubectl describe svc nginx-daemon-service
```

This Service selects all DaemonSet pods with the label:

```yaml
app: nginx-daemon-demo
```

That gives us one stable DNS name that can forward traffic to the nginx pods created by the DaemonSet.

---

## Testing the nginx content

Because all replicas mount the same `index.html` from the ConfigMap, they should all serve the same content.

Pick one of the pod names:

```bash
kubectl get pods -l app=nginx-rs-demo
```

Then inspect the html file inside that pod:

```bash
kubectl exec <pod-name> -- cat /usr/share/nginx/html/index.html
```

You should see the html that came from the ConfigMap.

You can also use `tester-pod` to request the ReplicaSet through the Service:

```bash
kubectl exec -it tester-pod -- bash
curl http://nginx-rs-service
exit
```

That is the normal Kubernetes way to reach a group of replicas.

The Service will load-balance traffic across the matching pods.

You can also request one pod directly by IP if you want:

```bash
kubectl get pods -l app=nginx-rs-demo -o wide
kubectl exec -it tester-pod -- bash
curl http://<pod-ip>
exit
```

Of course, replace `<pod-ip>` with one of the pod IPs from your cluster.

You can also test the DaemonSet Service:

```bash
kubectl exec -it tester-pod -- bash
curl http://nginx-daemon-service
exit
```

This should return the default nginx page from one of the DaemonSet pods.

---

## Scaling the ReplicaSet up and down

One of the main reasons to use a ReplicaSet is that it keeps a chosen number of pod replicas running.

We can change that number with:

```bash
kubectl scale rs nginx-rs-demo --replicas=5
```

Check the result:

```bash
kubectl get rs
kubectl get pods -l app=nginx-rs-demo
```

You should now see `5` pods managed by the ReplicaSet.

We can also scale back down:

```bash
kubectl scale rs nginx-rs-demo --replicas=2
```

Check again:

```bash
kubectl get rs
kubectl get pods -l app=nginx-rs-demo
```

Now you should see only `2` replicas left.

This is a very common workflow in Kubernetes.

Even though later we will usually work with Deployments instead of directly with ReplicaSets, this helps us understand the underlying mechanism.

---

## Updating the ConfigMap and restarting the replicas

Now let us change the html content stored in the ConfigMap.

Edit it with:

```bash
kubectl edit configmap nginx-index-config
```

Inside the editor, change the `index.html` content to something else, save it, and exit.

For example, you could change the heading text so it is easy to notice.

After that, inspect the ConfigMap:

```bash
kubectl describe configmap nginx-index-config
```

The ConfigMap object is now updated in Kubernetes.

However, our running pods will not automatically pick up this change in the way we mounted the file here.

That is because we mounted `index.html` using:

```yaml
subPath: index.html
```

With this style of mount, the container gets that file when it starts, and later ConfigMap updates are not automatically reflected inside the already running container.

So, even though the ConfigMap object changed, the existing pods keep using the old file content they started with.

We can prove that by checking one of the running pods before restarting anything:

```bash
kubectl get pods -l app=nginx-rs-demo
kubectl exec <pod-name> -- cat /usr/share/nginx/html/index.html
```

You should still see the old content there.

In order for the pods to mount the new file content, we need to recreate them.

So we will scale the ReplicaSet down to `0`:

```bash
kubectl scale rs nginx-rs-demo --replicas=0
kubectl get pods -l app=nginx-rs-demo
```

At this point, the old pods are gone.

Now scale it back up:

```bash
kubectl scale rs nginx-rs-demo --replicas=3
kubectl get pods -l app=nginx-rs-demo
```

New pods will be created, and they will mount the updated ConfigMap content.

To test the new content through the Service:

```bash
kubectl exec -it tester-pod -- bash
curl http://nginx-rs-service
exit
```

You should now see the updated html response.

We can also verify the file directly inside one of the recreated pods:

```bash
kubectl get pods -l app=nginx-rs-demo
kubectl exec <pod-name> -- cat /usr/share/nginx/html/index.html
```

This restart-by-scaling approach is a simple and clear way to demonstrate that new pods pick up the new configuration.

Later, when we discuss higher-level controllers, we will see more structured rollout strategies for config changes.

---

## Inspecting the Secret inside a pod

Pick one pod name again:

```bash
kubectl get pods -l app=nginx-rs-demo
```

### Reading the Secret as an environment variable

We injected the Secret as an environment variable called:

```text
APP_SECRET_MESSAGE
```

To print it:

```bash
kubectl exec <pod-name> -- printenv APP_SECRET_MESSAGE
```

### Reading the Secret as a mounted file

We also mounted the same Secret as a volume under:

```text
/etc/demo-secret
```

To list the files:

```bash
kubectl exec <pod-name> -- ls -l /etc/demo-secret
```

To read the mounted secret value:

```bash
kubectl exec <pod-name> -- cat /etc/demo-secret/secret-message
```

You should notice that the value is the same whether we read it from:

- the environment variable
- the mounted Secret file

That is because both are sourced from the same Secret object.

---

## ConfigMaps vs Secrets

At a practical level, Secrets often feel very similar to ConfigMaps.

Both can store key-value data.

Both can be consumed by pods as:

- environment variables
- mounted files

For learning purposes, you can think of a Secret as being a lot like a ConfigMap, except its values are intended for sensitive data and are stored encoded in YAML manifests.

That does **not** automatically mean they are magically secure in every possible sense, but it does mean Kubernetes treats them as a different type of resource meant for secret material.

For example, you can just see their value with

```bash
kubectl get secret my-secret -o yaml
```

And then just copy it and do:

```bash
echo "secret-value" | base64 -d
```

And boom, you have it in plaintext.

In real clusters, users and applications can be given different permissions for Secrets and ConfigMaps through Kubernetes roles and role bindings. Users can be denied viewing secrets.

We are not covering roles yet, but it is good to know that this distinction matters later.

---

## Cleaning up

To remove the resources from this lesson:

```bash
kubectl delete -f nginx-daemonset-service.yaml
kubectl delete -f nginx-daemonset.yaml
kubectl delete -f nginx-service.yaml
kubectl delete -f nginx-replicaset.yaml
kubectl delete -f nginx-secret.yaml
kubectl delete -f nginx-configmap.yaml
```

---

# [09 - Deployment and Probes](../09-nginx-deployment-and-probes/README.md)
