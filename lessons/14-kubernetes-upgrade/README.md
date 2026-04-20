[← Back to Lessons](../../README.md#lessons)

# Kubernetes upgrade

# Table of contents

- [Kubernetes upgrade](#kubernetes-upgrade)
- [What we will do](#what-we-will-do)
- [Prerequisites](#prerequisites)
- [Target versions](#target-versions)
- [Checking for deprecated features before upgrading](#checking-for-deprecated-features-before-upgrading)
- [Checking compatibility of extra cluster components](#checking-compatibility-of-extra-cluster-components)
- [Upgrading the control plane node](#upgrading-the-control-plane-node)
- [Upgrading k8s-worker-1](#upgrading-k8s-worker-1)
- [Upgrading k8s-worker-2](#upgrading-k8s-worker-2)
- [Verifying the cluster after the upgrade](#verifying-the-cluster-after-the-upgrade)

---

## Kubernetes upgrade

In this lesson, we will upgrade our kubeadm cluster from:

- Kubernetes `1.35.0-1.1`
- Cri-O `1.35.0-1.1`

to:

- Kubernetes `1.35.2-1.1`
- Cri-O `1.35.2-1.1`

We will follow the same installation style we used in lesson 03:

- `pkgs.k8s.io` for Kubernetes packages
- the openSUSE packaging repository for Cri-O

This time, instead of a fresh installation, we will do an in-place upgrade.

The high-level order is:

1. Check for deprecated features or API versions.
2. Upgrade the control plane node.
3. Upgrade worker nodes one at a time.
4. Verify that everything is healthy.

---

## What we will do

We will upgrade:

- `cri-o`
- `kubeadm`
- `kubelet`
- `kubectl`

And on the control plane node we will also run:

- `kubeadm upgrade plan`
- `kubeadm upgrade apply`

On each worker node we will run:

- `kubeadm upgrade node`

---

## Prerequisites

Before starting, make sure:

1. Your cluster is healthy and all nodes are `Ready`.
2. You can run `kubectl` from `k8s-master`.
3. Swap is still disabled.
4. Your package repositories are still configured as in lesson 03.
5. You have enough free disk space to pull updated images and packages.

Check the cluster first:

```bash
kubectl get nodes
kubectl get pods -A
```

You should also verify the currently installed versions on the machines:

```bash
kubeadm version
kubelet --version
kubectl version --client
crio --version
```

Because this is a patch upgrade inside the same minor version, the process is simpler than a minor version jump.

Still, we should treat it carefully.

Official kubeadm upgrade docs:

- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade
- https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-upgrade/

---

## Target versions

We are targeting these exact package versions:

```text
cri-o=1.35.2-1.1
kubeadm=1.35.2-1.1
kubelet=1.35.2-1.1
kubectl=1.35.2-1.1
```

Before installing them, it is a good idea to confirm that apt can see them.

Run on any node:

```bash
sudo apt-get update
sudo apt-cache madison cri-o
sudo apt-cache madison kubeadm
sudo apt-cache madison kubelet
sudo apt-cache madison kubectl
```

You should see `1.35.2-1.1` in the output.

---

## Checking for deprecated features before upgrading

Even though this is only a patch upgrade, it is a very good habit to check whether newer Kubernetes versions deprecate APIs or features your manifests and Helm charts might rely on.

There are 3 practical things we should check.

### 1. Read the Kubernetes deprecation guide

Official guide:

- https://kubernetes.io/docs/reference/using-api/deprecation-guide/

This guide shows which API versions were removed in which Kubernetes releases.

If you use an API version that is deprecated and later removed, your manifests or charts can fail after an upgrade.

This is not going to be our case but I will provide instructions.

### 2. Search your own manifests for apiVersion usage

From the project root (`cd /vagrant/`):


```bash
rg "^apiVersion:" lessons
```

This gives you a quick overview of which API groups and versions your manifests are using.

For example, if you ever found old beta APIs here, that would be a warning sign.

### 3. Render your Helm charts and inspect them

For local charts, render them first:

```bash
helm template nginxa lessons/10-helm-and-ingress/simple-nginx-chart \
  -f lessons/10-helm-and-ingress/values-nginxa.yaml
```

You can also grep the rendered output for `apiVersion`:

```bash
helm template nginxa lessons/10-helm-and-ingress/simple-nginx-chart \
  -f lessons/10-helm-and-ingress/values-nginxa.yaml | rg "^apiVersion:"
```

This is important because Helm charts may generate API objects that you do not notice just by reading values files.

### 4. Check whether the API server has seen deprecated APIs

Kubernetes exposes a metric for deprecated API usage.

Official deprecation policy:

- https://kubernetes.io/docs/reference/deprecation-policy/

That page documents the `apiserver_requested_deprecated_apis` metric.

If you have metrics collection in place, you can inspect that metric to see whether deprecated APIs are being requested.

For our small lab, the simplest practical checks are still:

- read the deprecation guide
- inspect `apiVersion` fields in your manifests
- render Helm charts and inspect their `apiVersion` fields

Helm also has its own documentation on deprecated Kubernetes APIs:

- https://helm.sh/docs/topics/kubernetes_apis/

For this repository specifically, the manifests and Helm chart we created in earlier lessons are already using stable API versions, so we do not expect problems here.

---

## Checking compatibility of extra cluster components

Kubernetes itself is not the only thing we need to think about.

Over the course of these lessons, we also installed extra cluster components that depend on Kubernetes APIs and cluster behavior.

In our case, that includes things like:

- Calico
- MetalLB
- the NFS CSI driver
- ingress-nginx

Even for a patch upgrade, it is worth checking that these components are still compatible with the target Kubernetes version.

### 1. Check what is currently installed

Run:

```bash
kubectl get pods -A
helm list -A
```

This gives you a quick overview of system add-ons and Helm-based installs.

### 2. Check Calico compatibility

We installed Calico in lesson 03 using manifests from:

```text
projectcalico/calico v3.31.4
```

Before upgrading Kubernetes, check the Calico release notes and compatibility guidance for the version you are using.

In practice, we mainly want to verify that:

- the Calico version supports Kubernetes 1.35
- there are no special upgrade steps for that Calico version

In the cluster, you can also quickly inspect the Calico images you are currently running:

```bash
kubectl get pods -n calico-system -o wide
kubectl get daemonset -n calico-system
```

Then `kubectl describe` them.

### 3. Check MetalLB compatibility

We installed MetalLB in lesson 06.

Before the Kubernetes upgrade, confirm:

- the MetalLB version you installed supports Kubernetes 1.35
- no CRD or API version used by MetalLB has been deprecated for your target version

You can inspect what is running with:

```bash
kubectl get pods -n metallb-system
kubectl get crd | rg metallb
```

Because MetalLB relies on CRDs and controllers, it is especially important that its CRDs remain valid for the target Kubernetes version.

### 4. Check the NFS CSI driver compatibility

We installed the NFS CSI driver in lesson 12 with Helm.

Before upgrading, check:

- whether the chart version you installed supports Kubernetes 1.35
- whether the driver release notes mention any upgrade requirements

Inspect what is installed:

```bash
helm list -n kube-system
kubectl get pods -n kube-system | rg nfs
kubectl get csidrivers
```

CSI drivers are very important to verify before upgrades, because broken storage integrations can affect stateful workloads.

### 5. Check ingress-nginx compatibility

We installed ingress-nginx in lesson 10 with Helm.

Before upgrading, confirm:

- the ingress-nginx chart version supports Kubernetes 1.35
- the chart is not using removed API versions

Inspect the release:

```bash
helm list -n ingress-nginx
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

You can also render or inspect the installed manifests:

```bash
helm get manifest ingress-nginx -n ingress-nginx | rg "^apiVersion:"
```

### 6. Why these checks matter

When people think about Kubernetes upgrades, they often focus only on:

- `kubeadm`
- `kubelet`
- `kubectl`

But real clusters also depend on:

- CNI plugins
- ingress controllers
- load balancer implementations
- CSI storage drivers
- the container runtime

If one of those components is incompatible, the cluster may technically upgrade but still have broken networking, storage, or ingress afterward.

So the safe mindset is:

```text
Do not only ask "Does Kubernetes upgrade?"
Also ask "Will the add-ons my workloads depend on still work after the upgrade?"
```

For our small lab and this patch upgrade, we do not expect any major incompatibility, but it is still a very good habit to check these things every time.

---

## Upgrading the control plane node

We start on `k8s-master`.

### 1. Drain the node

From `k8s-master`, run:

```bash
kubectl drain k8s-master --ignore-daemonsets --delete-emptydir-data
```

Because your control plane node does not host normal worker workloads in this lab, this drain should mostly affect helper or test pods that may have landed there.

### 2. Upgrade kubeadm first

```bash
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.35.2-1.1
sudo apt-mark hold kubeadm
```

Check it:

```bash
kubeadm version
```

### 3. Review the upgrade plan

```bash
sudo kubeadm upgrade plan v1.35.2
```

This shows what kubeadm intends to upgrade and confirms the cluster is in an upgradeable state.

### 4. Apply the control plane upgrade

```bash
sudo kubeadm upgrade apply v1.35.2
```

Wait for it to complete successfully.

### 5. Upgrade Cri-O, kubelet and kubectl

```bash
sudo apt-mark unhold cri-o kubelet kubectl
sudo apt-get update
sudo apt-get install -y \
  cri-o=1.35.2-1.1 \
  kubelet=1.35.2-1.1 \
  kubectl=1.35.2-1.1
sudo apt-mark hold cri-o kubelet kubectl
```

### 6. Restart services

```bash
sudo systemctl daemon-reload
sudo systemctl restart crio
sudo systemctl restart kubelet
```

### 7. Check the node

```bash
kubectl get nodes
sudo systemctl status crio --no-pager
sudo systemctl status kubelet --no-pager
```

It should say that it's ready and have the new version.

With the following, you can actually see the cri-o version too:

```bash
kubectl get nodes -o wide
```

---

### 8. Uncordon the node

```bash
kubectl uncordon k8s-master
```

## Upgrading k8s-worker-1

Now connect to `k8s-worker-1`.

### 1. Upgrade kubeadm

```bash
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.35.2-1.1
sudo apt-mark hold kubeadm
```

### 2. Drain the node from k8s-master

From `k8s-master`, run:

```bash
kubectl drain k8s-worker-1 --ignore-daemonsets --delete-emptydir-data
```

### 3. Upgrade the node configuration

Back on `k8s-worker-1`, run:

```bash
sudo kubeadm upgrade node
```

### 4. Upgrade Cri-O, kubelet and kubectl

```bash
sudo apt-mark unhold cri-o kubelet kubectl
sudo apt-get update
sudo apt-get install -y \
  cri-o=1.35.2-1.1 \
  kubelet=1.35.2-1.1 \
  kubectl=1.35.2-1.1
sudo apt-mark hold cri-o kubelet kubectl
```

### 5. Restart services

```bash
sudo systemctl daemon-reload
sudo systemctl restart crio
sudo systemctl restart kubelet
```

### 6. Inspect the node

From `k8s-master`:

```bash
kubectl get nodes -o wide
```

It should show up as ready and you should see the new version.

If any problems occur, this is where you have to do `systemctl status kubelet` and start figuring out what went wrong.

### 7. Uncordon the node from k8s-master

Back on `k8s-master`:

```bash
kubectl uncordon k8s-worker-1
```

---

## Upgrading k8s-worker-2

Now connect to `k8s-worker-2`.

### 1. Upgrade kubeadm

```bash
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.35.2-1.1
sudo apt-mark hold kubeadm
```

### 2. Drain the node from k8s-master

From `k8s-master`, run:

```bash
kubectl drain k8s-worker-2 --ignore-daemonsets --delete-emptydir-data
```

### 3. Upgrade the node configuration

Back on `k8s-worker-2`, run:

```bash
sudo kubeadm upgrade node
```

### 4. Upgrade Cri-O, kubelet and kubectl

```bash
sudo apt-mark unhold cri-o kubelet kubectl
sudo apt-get update
sudo apt-get install -y \
  cri-o=1.35.2-1.1 \
  kubelet=1.35.2-1.1 \
  kubectl=1.35.2-1.1
sudo apt-mark hold cri-o kubelet kubectl
```

### 5. Restart services

```bash
sudo systemctl daemon-reload
sudo systemctl restart crio
sudo systemctl restart kubelet
```

### 6. Inspect the node

From `k8s-master`:

```bash
kubectl get nodes -o wide
```

It should show up as ready and you should see the new version.

### 7. Uncordon the node from k8s-master

Back on `k8s-master`:

```bash
kubectl uncordon k8s-worker-2
```

---

## Verifying the cluster after the upgrade

Back on `k8s-master`, verify the final state:

```bash
kubectl get nodes
kubectl get pods -A
```

You should see all nodes as `Ready`, and their Kubernetes version should now be:

```text
v1.35.2
```

You can also verify package versions on each node:

```bash
kubeadm version
kubelet --version
kubectl version --client
crio --version
```

If something went wrong during a kubeadm upgrade, remember that `kubeadm upgrade` is designed to be idempotent and can often simply be run again after the underlying issue is fixed.

---

# [15 - etcd Backups and Restores](../15-etcd-backups-and-restores/README.md)
