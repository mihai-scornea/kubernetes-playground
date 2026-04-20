[← Back to Lessons](../../README.md#lessons)

# First pods

# Table of contents

- [First pods](#first-pods)
- [What we will create](#what-we-will-create)
- [Prerequisites](#prerequisites)
- [The YAML files](#the-yaml-files)
- [Creating the resources](#creating-the-resources)
- [Viewing the hello world logs](#viewing-the-hello-world-logs)
- [Understanding kubectl describe](#understanding-kubectl-describe)
- [Using kubectl exec](#using-kubectl-exec)
- [Pod IPs](#pod-ips)
- [Cleaning up](#cleaning-up)

---

## First pods

In this lesson, we will create our first 2 pods with plain Kubernetes YAML files.

The first pod will simply print:

```text
Hello, World! :D
```

and then exit.

The second pod will run an nginx image from our private registry:

```text
k8s-master:8082/nginx:1.25-custom-index
```

Because that image is in a private registry, we will also create an image pull secret for it.

---

## What we will create

We will use these files:

- `hello-world-pod.yaml`
- `registry-secret.yaml`
- `custom-nginx-pod.yaml`

---

## Prerequisites

Before running these examples, make sure:

1. Your Kubernetes cluster is up and working.
2. Your nodes can pull images from the insecure registry `k8s-master:8082`.
3. The `k8s-master:8082/nginx:1.25-custom-index` image already exists in our Nexus registry.

We already configured this earlier in the Kubernetes installation lesson when we edited:

```bash
/etc/containers/registries.conf
```

and restarted `crio`.

If that step was not done on all nodes, the nginx pod will fail to pull its image.

---

## The YAML files

### The hello world pod

This pod uses a very small container, prints a message, and exits.

Notice the important part:

```yaml
restartPolicy: Never
```

This tells Kubernetes not to restart the pod after the container finishes.

### The registry secret

This file creates a Kubernetes secret of type `kubernetes.io/dockerconfigjson`.

It contains the credentials for:

- Username: `kube-user`
- Password: `123123123`
- Registry: `k8s-master:8082`

Kubernetes will use this secret when pulling the private nginx image.

### The custom nginx pod

This pod starts the image:

```text
k8s-master:8082/nginx:1.25-custom-index
```

It references the pull secret with:

```yaml
imagePullSecrets:
- name: private-registry-credentials
```

That is what allows Kubernetes to authenticate to the registry.

---

## Creating the resources

Go into this lesson directory:

```bash
cd /vagrant/lessons/04-first-pods
```

Create the secret first:

```bash
kubectl apply -f registry-secret.yaml
```

This file was created using the following command:
```bash
kubectl create secret docker-registry private-registry-credentials \
  --docker-server=k8s-master:8082 \
  --docker-username=kube-user \
  --docker-password=123123123 \
  --dry-run=client -o yaml
```

Create the hello world pod:

```bash
kubectl apply -f hello-world-pod.yaml
```

Create the custom nginx pod:

```bash
kubectl apply -f custom-nginx-pod.yaml
```

You can then check their status with:

```bash
kubectl get pods
```

You should see:

- `hello-world` finish with `Completed`
- `custom-nginx` reach `Running`

---

## Viewing the hello world logs

The hello world pod exits very quickly, but its logs are still available.

To view them:

```bash
kubectl logs hello-world
```

You should get:

```text
Hello, World! :D
```

This is one of the most common ways to inspect what happened inside a container that already finished.

---

## Understanding kubectl describe

The `kubectl describe` command gives us detailed information about a Kubernetes resource.

For a pod, it shows things like:

- The node where it was scheduled
- The image it is using
- The pod IP
- Container state
- Restart count
- Events such as image pulls, starts, failures, or scheduling problems

For example:

```bash
kubectl describe pod hello-world
```

and:

```bash
kubectl describe pod custom-nginx
```

This command is extremely useful when something is not working.

For example, if an image cannot be pulled, `kubectl describe` will usually show events near the bottom such as authentication failures, DNS problems, or registry connection errors.

If you want an even more in-depth look, you can use:

```bash
kubectl get pods custom-nginx -o yaml
```

This will show you the actual yaml file of your pod generated from the data stored in the etcd database.

---

## Using kubectl exec

The `kubectl exec` command lets us run a command inside a running container.

This is useful when we want to:

- Inspect files
- Check environment variables
- Test networking from inside the pod
- Open a shell in the container

To open a shell inside the custom nginx pod:

```bash
kubectl exec -it custom-nginx -- bash
```

Once inside, run:

```bash
curl localhost:80
```

This sends an HTTP request to the nginx server from inside the container itself.

If the pod is working, you should see the custom HTML page returned by nginx.

When you are done, exit the shell:

```bash
exit
```

You can also run the curl directly without opening an interactive shell:

```bash
kubectl exec custom-nginx -- curl localhost
```

---

## Pod IPs:

We can see the IPs of our pods using:

```bash
kubectl get pods -o wide
```

We can actually query their IPs from their host machines.

But if we delete a pod and start it up again, it changes its IP.

```bash
kubectl delete -f custom-nginx-pod.yaml
kubectl apply -f custom-nginx-pod.yaml
kubectl get pods -o wide
```

In the next lesson, we will see how we can make our pods easier to access.

## Cleaning up

To remove these resources:

```bash
kubectl delete -f custom-nginx-pod.yaml
kubectl delete -f hello-world-pod.yaml
```

We will keep our registry secret there so that we can pull images from our Nexus in further examples.

---

# [05 - Debugging and Testing Pods](../05-debugging-and-testing-pods/README.md)
