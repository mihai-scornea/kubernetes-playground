[← Back to Lessons](../../README.md#lessons)

# StatefulSets and persistent volumes

# Table of contents

- [StatefulSets and persistent volumes](#statefulsets-and-persistent-volumes)
- [What we will create](#what-we-will-create)
- [Prerequisites](#prerequisites)
- [Setting up the NFS server on k8s-master](#setting-up-the-nfs-server-on-k8s-master)
- [Installing the NFS CSI driver](#installing-the-nfs-csi-driver)
- [Creating the NFS StorageClass](#creating-the-nfs-storageclass)
- [Creating the StatefulSet](#creating-the-statefulset)
- [Writing different files into each pod volume](#writing-different-files-into-each-pod-volume)
- [Draining a node and watching the pod move](#draining-a-node-and-watching-the-pod-move)
- [Verifying the data is still there](#verifying-the-data-is-still-there)
- [Query the statefulset pods individually through the headless service](#query-the-statefulset-pods-individually-through-the-headless-service)
- [Cleaning up](#cleaning-up)

---

## StatefulSets and persistent volumes

In this lesson, we will use:

- an NFS server running on `k8s-master`
- the NFS CSI driver
- a Kubernetes `StorageClass`
- a `StatefulSet` with `2` replicas

The goal is to show that a StatefulSet pod can keep its own data even if it gets rescheduled onto a different node.

Each pod in a StatefulSet gets its own stable volume claim.

When a pod is recreated, Kubernetes reconnects that pod identity to the same persistent storage.

That is exactly what we want to demonstrate.

---

## What we will create

We will use these files:

- `nfs-storageclass.yaml`
- `statefulset-headless-service.yaml`
- `demo-statefulset.yaml`

---

## Prerequisites

Before running these examples, make sure:

1. Your Kubernetes cluster is up and working.
2. Helm is installed on `k8s-master`.
3. Your worker nodes can reach `k8s-master` over the network.
4. Your normal workload pods schedule on `k8s-worker-1` and `k8s-worker-2`.
5. Your nodes can pull the public image `busybox:1.36.1`.

This lesson is based on Canonical's MicroK8s NFS guide, but adapted for your kubeadm cluster on 3 VMs.

Canonical guide used as reference:

- https://canonical.com/microk8s/docs/how-to-nfs

---

## Setting up the NFS server on k8s-master

This part follows the same basic idea as the Canonical guide, but we will run the commands directly on `k8s-master`.

On `k8s-master`, install the NFS server:

```bash
sudo apt-get update
sudo apt-get install -y nfs-kernel-server
```

Create the directory that will be exported:

```bash
sudo mkdir -p /srv/nfs
sudo chown nobody:nogroup /srv/nfs
sudo chmod 0777 /srv/nfs
```

Configure the export.

Our cluster nodes are on the `192.168.50.0/24` network, so export the share to that subnet:

```bash
sudo cp /etc/exports /etc/exports.bak
echo '/srv/nfs 192.168.50.0/24(rw,sync,no_subtree_check)' | sudo tee /etc/exports
```

Restart the NFS server:

```bash
sudo systemctl restart nfs-kernel-server
```

Check that it is exporting correctly:

```bash
sudo exportfs -v
```

You should see `/srv/nfs` exported to your lab subnet.

---

## Installing the NFS CSI driver

We will use the upstream NFS CSI driver through its Helm chart, just like the Canonical guide does.

On `k8s-master`, add the repository:

```bash
helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm repo update
```

Install the chart in `kube-system`:

```bash
helm upgrade --install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
  --namespace kube-system
```

Wait for the pods:

```bash
kubectl wait pod \
  --selector app.kubernetes.io/name=csi-driver-nfs \
  --for condition=Ready \
  --namespace kube-system \
  --timeout=180s
```

Check that the CSI driver exists:

```bash
kubectl get csidrivers
```

You should see:

```text
nfs.csi.k8s.io
```

---

## Creating the NFS StorageClass

Now create the `StorageClass`:

```bash
cd /vagrant/lessons/12-statefulsets-and-persistent-volumes
kubectl apply -f nfs-storageclass.yaml
```

Check it:

```bash
kubectl get storageclass
kubectl describe storageclass nfs-csi
```

This `StorageClass` points to:

- server: `192.168.50.10`
- share: `/srv/nfs`

That is the `k8s-master` machine and the NFS export we created earlier.

---

## Creating the StatefulSet

First create the headless service:create the StatefulSet:

```bash
kubectl apply -f demo-statefulset.yaml
```

Then create the headless service:

```bash
kubectl apply -f statefulset-headless-service.yaml
```

Check what was created:

```bash
kubectl get statefulset
kubectl get pods -l app=nfs-stateful-demo -o wide
kubectl get pvc
```

You should see:

- `nfs-stateful-demo-0`
- `nfs-stateful-demo-1`

and two PVCs, one for each pod.

This is one of the important differences between a StatefulSet and a Deployment.

Each StatefulSet replica gets its own stable identity and its own stable volume claim.

In this example, each PVC only requests `10Mi`, which is plenty for our small file-based demo.

We also gave the pod template a preferred pod anti-affinity rule so Kubernetes tries to place the 2 replicas on different worker nodes when possible.

---

## Writing different files into each pod volume

Each pod mounts its own persistent volume at:

```text
/data
```

Create one file in the first pod:

```bash
kubectl exec nfs-stateful-demo-0 -- sh -c 'echo "This file belongs to pod 0" > /data/pod0.txt'
```

Create a different file in the second pod:

```bash
kubectl exec nfs-stateful-demo-1 -- sh -c 'echo "This file belongs to pod 1" > /data/pod1.txt'
```

Check them:

```bash
kubectl exec nfs-stateful-demo-0 -- ls -l /data
kubectl exec nfs-stateful-demo-0 -- cat /data/pod0.txt
kubectl exec nfs-stateful-demo-1 -- ls -l /data
kubectl exec nfs-stateful-demo-1 -- cat /data/pod1.txt
```

At this point, each pod should have its own different file in its own persistent volume.

---

## Draining a node and watching the pod move

Now we will drain one worker node.

First, see where the pods are:

```bash
kubectl get pods -l app=nfs-stateful-demo -o wide
```

Pick one of the worker nodes that currently hosts one of the StatefulSet pods.

For example, if one pod is on `k8s-worker-1`, drain that node:

```bash
kubectl drain k8s-worker-1 --ignore-daemonsets --delete-emptydir-data
```

Now watch the pods:

```bash
kubectl get pods -l app=nfs-stateful-demo -o wide -w
```

What should happen:

- the pod on the drained node is terminated
- Kubernetes recreates it
- the recreated pod comes up on the remaining schedulable worker node

Because we only have 2 worker nodes for normal workloads, both StatefulSet pods may end up on the same remaining worker after the drain.

That is fine for this lesson.

After the pod is back, stop the watch with:

```bash
ctrl+c
```

Then uncordon the drained node so it becomes schedulable again:

```bash
kubectl uncordon k8s-worker-1
```

---

## Verifying the data is still there

Now check the files again:

```bash
kubectl exec nfs-stateful-demo-0 -- ls -l /data
kubectl exec nfs-stateful-demo-0 -- cat /data/pod0.txt
kubectl exec nfs-stateful-demo-1 -- ls -l /data
kubectl exec nfs-stateful-demo-1 -- cat /data/pod1.txt
```

Even if one of the pods moved to a different node, it should still have its original file.

That is the key point of the lesson:

- the pod identity stayed the same
- the PVC stayed the same
- the underlying persistent data stayed the same
- Kubernetes reattached that pod identity to the same storage

This is why StatefulSets are so useful for stateful workloads.

---

## Query the statefulset pods individually through the headless service:

You need to use the name of the pod, followed by the fully qualified domain name of the headless service.

```bash
kubectl exec -it tester-static-pod-k8s-master -- curl nfs-stateful-demo-0.nfs-stateful-demo.default.svc.cluster.local
kubectl exec -it tester-static-pod-k8s-master -- curl nfs-stateful-demo-0.nfs-stateful-demo.default.svc.cluster.local
```

## Cleaning up

To remove the StatefulSet resources:

```bash
kubectl delete -f demo-statefulset.yaml
kubectl delete -f statefulset-headless-service.yaml
kubectl delete -f nfs-storageclass.yaml
```

To delete the PVCs:

```bash
kubectl delete pvc data-nfs-stateful-demo-0
kubectl delete pvc data-nfs-stateful-demo-1
```

To remove the CSI driver:

```bash
helm uninstall csi-driver-nfs -n kube-system
```

If you also want to remove the NFS server setup from `k8s-master`, you can undo it manually later.

---

# [13 - User Access](../13-user-access/README.md)
