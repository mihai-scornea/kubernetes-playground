[← Back to Lessons](../../README.md#lessons)

# Debugging and testing pods

# Table of contents

- [Debugging and testing pods](#debugging-and-testing-pods)
- [What we will create](#what-we-will-create)
- [Prerequisites](#prerequisites)
- [Creating the pods](#creating-the-pods)
- [Creating a static pod through the kubelet](#creating-a-static-pod-through-the-kubelet)
- [Inspecting the pods](#inspecting-the-pods)
- [Using kubectl exec](#using-kubectl-exec)
- [Testing pod to pod communication](#testing-pod-to-pod-communication)
- [Using kubectl port-forward](#using-kubectl-port-forward)
- [Using an SSH tunnel from Windows](#using-an-ssh-tunnel-from-windows)
- [Cleaning up](#cleaning-up)

---

## Debugging and testing pods

In this lesson, we will create 2 pods that help us practice basic debugging and testing workflows.

The first pod will run the official nginx image:

```text
nginx:1.25
```

The second pod will be a toolbox pod called `tester-pod`.

It will stay running and give us useful commands such as `bash` and `curl` so that we can test connectivity from inside the cluster.

---

## What we will create

We will use these files:

- `nginx-debug-pod.yaml`
- `tester-pod.yaml`
- `tester-static-pod.yaml`

---

## Prerequisites

Before running these examples, make sure:

1. Your Kubernetes cluster is up and working.
2. Your nodes can pull the public image `nginx:1.25`.

---

## Creating the pods

Go into this lesson directory:

```bash
cd /vagrant/lessons/05-debugging-and-testing-pods
```

Create the nginx pod:

```bash
kubectl apply -f nginx-debug-pod.yaml
```

Create the tester pod:

```bash
kubectl apply -f tester-pod.yaml
```

Check that both pods are running:

```bash
kubectl get pods -o wide
```

You should see both:

- `nginx-debug`
- `tester-pod`

The `-o wide` part also shows the pod IPs and the node where each pod is running.

---

## Creating a static pod through the kubelet

Kubernetes is not the only way a pod can appear on a node.

The kubelet can also watch a local folder for manifest files and create pods directly from them.

On kubeadm clusters, that folder is usually:

```bash
/etc/kubernetes/manifests
```

This is how the control plane static pods are usually managed.

We can demonstrate that by copying our extra tester manifest there on `k8s-master`.

On `k8s-master`, run:

```bash
sudo cp /vagrant/lessons/05-debugging-and-testing-pods/tester-static-pod.yaml /etc/kubernetes/manifests/
```

Then check the pods from Kubernetes:

```bash
kubectl get pods -o wide
```

You should see a pod created from that manifest.

Because it is a static pod managed by the kubelet on `k8s-master`, Kubernetes usually shows a mirror pod with a name like:

- `tester-static-pod-k8s-master`

If you want to remove it later, delete the manifest file from the kubelet manifests folder:

```bash
sudo rm /etc/kubernetes/manifests/tester-static-pod.yaml
```

But keep it there. You can use it in case your other tester pod gets evicted.

---

## Inspecting the pods

One of the most useful commands for debugging is:

```bash
kubectl describe pod nginx-debug
```

This shows us details such as:

- Which node the pod was scheduled on
- Which image it is using
- The pod IP
- Container state
- Events near the bottom

Those events are especially useful when something goes wrong.

For example, they can show:

- Image pull failures
- Authentication problems
- Scheduling problems
- Container crashes

We can do the same for the tester pod:

```bash
kubectl describe pod tester-pod
```

If we want to see the full Kubernetes object stored in the cluster, we can also run:

```bash
kubectl get pod nginx-debug -o yaml
```

---

## Using kubectl exec

The `kubectl exec` command allows us to run commands inside a running container.

This is extremely useful for debugging because we can inspect the environment from inside the pod itself.

For example, we can inspect files inside our nginx pod with:

```bash
kubectl exec nginx-debug -- ls /usr/share/nginx/html
```

That lets us see the files nginx serves.

For interactive testing, the better target is our `tester-pod`, because it has both `bash` and `curl`.

To open a shell inside the tester pod:

```bash
kubectl exec -it tester-pod -- bash
```

Once inside, you can run whatever tests you want.

For example:

```bash
curl --version
```

When you are done:

```bash
exit
```

This pod is useful specifically because it stays alive and gives us a place from which we can test other pods.

---

## Testing pod to pod communication

Pods in the cluster can communicate with each other over the pod network.

First, find the IP of the nginx pod:

```bash
kubectl get pod nginx-debug -o wide
```

You will see a pod IP in the output, something like:

```text
10.244.1.12
```

Now open a shell inside the tester pod:

```bash
kubectl exec -it tester-pod -- bash
```

From inside `tester-pod`, curl the IP of the nginx pod:

```bash
curl 10.244.1.12
```

Of course, replace `10.244.1.12` with the actual IP you got from your cluster.

If everything is working, you should receive the HTML served by the nginx debug pod.

This proves that the pods can talk to each other over the Kubernetes pod network.

When you are done, exit the tester pod:

```bash
exit
```

---

## Using kubectl port-forward

Sometimes we want to access a pod locally from the machine where we are running `kubectl`.

We can do that with:

```bash
kubectl port-forward pod/nginx-debug 8089:80
```

This means:

- Local port `8089` on the machine where you run `kubectl`
- Forwarded to port `80` inside `nginx-debug`

After that, from that same machine, you can open:

```text
localhost:8089
```

or run:

```bash
curl localhost:8089
```

and you should see the nginx page returned by the pod.

This is very useful for quick local testing without exposing the pod through a Service or Ingress.

---

## Using an SSH tunnel from Windows

If `kubectl port-forward` is running on your Linux machine, you can also reach that forwarded port from your Windows machine through an SSH tunnel.

For example, if you run this on `k8s-master`:

```bash
kubectl port-forward pod/nginx-debug 8089:80
```

then the pod becomes reachable on `127.0.0.1:8089` on `k8s-master`.

If you create an SSH tunnel in SuperPuTTY from your Windows machine to `k8s-master`, you can forward:

- Windows local port `8080`
- To `localhost:8089` on `k8s-master`

After that, on your Windows machine, you can open:

```text
localhost:8089
```

and see the pod output in your browser.

So the full chain becomes:

```text
Windows browser -> SSH tunnel -> k8s-master:localhost:8089 -> kubectl port-forward -> pod port 80
```

This is a very convenient way to view pod output on Windows even though the Kubernetes tools are running inside the Linux VM.

---

## Cleaning up

At the end of this lesson, we will delete the nginx debug pod but keep the testing pod.

You can also ctrl+c the kubectl port-forward process.

Delete only the nginx pod:

```bash
kubectl delete -f nginx-debug-pod.yaml
```

Confirm what remains:

```bash
kubectl get pods
```

You should still have:

- `tester-pod`

We keep it because it will continue to be useful for testing in later examples.

We should also still have the static `tester-static-pod-k8s-master` pod.

We will also keep that one.

---

# [06 - Nginx with Services](../06-nginx-with-services/README.md)
