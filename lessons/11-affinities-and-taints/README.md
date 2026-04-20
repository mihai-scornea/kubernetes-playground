[← Back to Lessons](../../README.md#lessons)

# Affinities and taints

# Table of contents

- [Affinities and taints](#affinities-and-taints)
- [What we will create](#what-we-will-create)
- [Prerequisites](#prerequisites)
- [The fly and mosquito pods](#the-fly-and-mosquito-pods)
- [Applying the mosquito-spray taint](#applying-the-mosquito-spray-taint)
- [Scheduling the fly pod](#scheduling-the-fly-pod)
- [Removing the mosquito-spray taint](#removing-the-mosquito-spray-taint)
- [Scheduling the mosquito pod](#scheduling-the-mosquito-pod)
- [Applying the fly-spray NoExecute taint](#applying-the-fly-spray-noexecute-taint)
- [Applying mosquito-spray again with NoSchedule](#applying-mosquito-spray-again-with-noschedule)
- [Preferred anti-affinity](#preferred-anti-affinity)
- [Required anti-affinity](#required-anti-affinity)
- [Cleaning up](#cleaning-up)

---

## Affinities and taints

In this lesson, we will look at two different scheduling ideas:

- taints and tolerations
- pod anti-affinity

Taints are applied to nodes.

Tolerations are applied to pods.

A taint says:

```text
Pods should stay away from this node unless they explicitly tolerate this taint.
```

Pod anti-affinity works differently.

It lets us express rules like:

```text
Try not to place these pods on the same node.
```

or:

```text
Do not place these pods on the same node.
```

---

## What we will create

We will use these files:

- `fly-pod.yaml`
- `mosquito-pod.yaml`
- `preferred-spread-deployment.yaml`
- `required-spread-deployment.yaml`

---

## Prerequisites

Before running these examples, make sure:

1. Your Kubernetes cluster is up and working.
2. Your nodes can pull the public image `busybox:1.36.1`.
3. Your normal workload pods schedule only on `k8s-worker-1` and `k8s-worker-2`.

In this lab, `k8s-master` does not take normal worker workloads.

That matters a lot for the anti-affinity examples, because we effectively have only 2 schedulable nodes for these pods.

---

## The fly and mosquito pods

We will use 2 pods:

- `fly`
- `mosquito`

The `fly` pod has a toleration for:

```text
mosquito-spray
```

The `mosquito` pod has a toleration for:

```text
fly-spray
```

Each pod runs `sh -c "trap 'exit 0' TERM; while true; do sleep 1; done"` so it stays alive while also shutting down cleanly when Kubernetes sends `TERM`.

---

## Applying the mosquito-spray taint

First, let us taint all 3 nodes with:

- key: `mosquito-spray`
- effect: `NoSchedule`

Run:

```bash
kubectl taint nodes k8s-master mosquito-spray=true:NoSchedule
kubectl taint nodes k8s-worker-1 mosquito-spray=true:NoSchedule
kubectl taint nodes k8s-worker-2 mosquito-spray=true:NoSchedule
```

Check the taints:

```bash
kubectl describe node k8s-master
kubectl describe node k8s-worker-1
kubectl describe node k8s-worker-2
```

At this point, new pods that do not tolerate `mosquito-spray` should not be scheduled on those nodes.

Note that the `mosquito-spray` taint doesn't only affect the mosquito pod in our example, it affects ALL pods that do not have a toleration for it.

---

## Scheduling the fly pod

Now create the `fly` pod:

```bash
cd /vagrant/lessons/11-affinities-and-taints
kubectl apply -f fly-pod.yaml
```

Check it:

```bash
kubectl get pods -o wide
kubectl describe pod fly
```

The `fly` pod can be scheduled because it has a toleration for:

```text
mosquito-spray
```

In practice, it should still land on one of the worker nodes, because `k8s-master` is not accepting normal workload pods in your setup.

Try creating the `mosquito` pod now if you want:

```bash
kubectl apply -f mosquito-pod.yaml
kubectl get pods
kubectl describe pod mosquito
```

It should stay `Pending` at this stage, because it does **not** tolerate `mosquito-spray`.

---

## Removing the mosquito-spray taint

Now remove the `mosquito-spray` taint from all nodes:

```bash
kubectl taint nodes k8s-master mosquito-spray-
kubectl taint nodes k8s-worker-1 mosquito-spray-
kubectl taint nodes k8s-worker-2 mosquito-spray-
```

This opens the nodes back up for normal scheduling.

---

## Scheduling the mosquito pod

If your `mosquito` pod was `Pending`, it should now be able to schedule.

If you deleted it earlier, create it now:

```bash
kubectl apply -f mosquito-pod.yaml
```

Check both pods:

```bash
kubectl get pods -o wide
```

Now both should be running.

The `mosquito` pod has a toleration for:

```text
fly-spray
```

That will matter in the next step.

---

## Applying the fly-spray NoExecute taint

Now taint all nodes with:

- key: `fly-spray`
- effect: `NoExecute`

Run:

```bash
kubectl taint nodes k8s-master fly-spray=true:NoExecute
kubectl taint nodes k8s-worker-1 fly-spray=true:NoExecute
kubectl taint nodes k8s-worker-2 fly-spray=true:NoExecute
```

Note that this will also remove your normal `tester-pod`, because it is just a regular pod without a toleration for `fly-spray`.

However, the static tester pod we created earlier in lesson 05 on `k8s-master` is different (if you still have it there :D).

That one is managed directly by the kubelet from the manifests folder, so even if Kubernetes removes the mirror pod object, the kubelet will keep trying to recreate it from the file in `/etc/kubernetes/manifests`.

Then check the pods:

```bash
kubectl get pods -o wide
```

What should happen:

- `fly` should be evicted
- `mosquito` should stay

This is because `NoExecute` does two things:

- it prevents scheduling onto tainted nodes
- it also evicts already-running pods that do not tolerate the taint

The `fly` pod does not tolerate `fly-spray`, so it goes away.

The `mosquito` pod **does** tolerate `fly-spray`, so it stays running.

---

## Applying mosquito-spray again with NoSchedule

Now apply the `mosquito-spray` taint again, but with `NoSchedule`:

```bash
kubectl taint nodes k8s-master mosquito-spray=true:NoSchedule
kubectl taint nodes k8s-worker-1 mosquito-spray=true:NoSchedule
kubectl taint nodes k8s-worker-2 mosquito-spray=true:NoSchedule
```

Check the pods again:

```bash
kubectl get pods -o wide
```

The `mosquito` pod should **not** be kicked out.

That is the important difference:

- `NoSchedule` affects future scheduling
- `NoExecute` can evict already-running pods

So even though `mosquito` does not tolerate `mosquito-spray`, it will stay running because `NoSchedule` does not evict existing pods.

---

## Preferred anti-affinity

Now let us look at pod anti-affinity.

Before we do that, remove the taints we used earlier so new pods can schedule normally:

```bash
kubectl taint nodes k8s-master mosquito-spray-
kubectl taint nodes k8s-worker-1 mosquito-spray-
kubectl taint nodes k8s-worker-2 mosquito-spray-
kubectl taint nodes k8s-master fly-spray-
kubectl taint nodes k8s-worker-1 fly-spray-
kubectl taint nodes k8s-worker-2 fly-spray-
```

Create the preferred-spread Deployment:

```bash
kubectl apply -f preferred-spread-deployment.yaml
```

Check where the pods landed:

```bash
kubectl get pods -l app=preferred-spread -o wide
```

This Deployment has `3` replicas and a pod anti-affinity rule that says:

```text
Try to avoid putting these pods on the same node.
```

Because this rule is only preferred, Kubernetes will try to spread them out, but it is allowed to place multiple replicas on the same node if needed.

In our setup, because only the 2 worker nodes are schedulable, Kubernetes will usually spread the first 2 pods across the 2 workers and then place the third pod on one of those workers as well.

But this is a preference, not a hard requirement.

---

## Required anti-affinity

Now create the required-spread Deployment:

```bash
kubectl apply -f required-spread-deployment.yaml
```

Check where the pods landed:

```bash
kubectl get pods -l app=required-spread -o wide
```

This Deployment also has `3` replicas, but its anti-affinity rule says:

```text
These pods must not be on the same node.
```

That is a hard requirement.

In our setup, only the 2 worker nodes are available for these pods.

So Kubernetes can place at most:

- one replica on `k8s-worker-1`
- one replica on `k8s-worker-2`

The third replica should stay `Pending`, because the anti-affinity rule says these pods must not share a node and `k8s-master` is not available for normal workload scheduling.

---

## Cleaning up

To remove the resources from this lesson:

```bash
kubectl delete -f required-spread-deployment.yaml --ignore-not-found
kubectl delete -f preferred-spread-deployment.yaml --ignore-not-found
kubectl delete -f mosquito-pod.yaml --ignore-not-found
kubectl delete -f fly-pod.yaml --ignore-not-found
```

To remove the taints we used:

```bash
kubectl taint nodes k8s-master mosquito-spray-
kubectl taint nodes k8s-worker-1 mosquito-spray-
kubectl taint nodes k8s-worker-2 mosquito-spray-
kubectl taint nodes k8s-master fly-spray-
kubectl taint nodes k8s-worker-1 fly-spray-
kubectl taint nodes k8s-worker-2 fly-spray-
```

---

# [12 - StatefulSets and Persistent Volumes](../12-statefulsets-and-persistent-volumes/README.md)
