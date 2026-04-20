[← Back to Lessons](../../README.md#lessons)

# etcd backups and restores

# Table of contents

- [etcd backups and restores](#etcd-backups-and-restores)
- [What we will do](#what-we-will-do)
- [Prerequisites](#prerequisites)
- [Why etcd backups matter](#why-etcd-backups-matter)
- [Checking the etcd static pod setup](#checking-the-etcd-static-pod-setup)
- [Installing etcdctl locally on k8s-master](#installing-etcdctl-locally-on-k8s-master)
- [Creating an etcd snapshot backup](#creating-an-etcd-snapshot-backup)
- [Inspecting the snapshot](#inspecting-the-snapshot)
- [Restoring the snapshot in a kubeadm lab](#restoring-the-snapshot-in-a-kubeadm-lab)
- [Bringing the control plane back up](#bringing-the-control-plane-back-up)
- [Verifying the restore](#verifying-the-restore)
- [Cleaning up](#cleaning-up)

---

## etcd backups and restores

In this lesson, we will back up and restore `etcd`.

`etcd` is the key-value database where Kubernetes stores cluster state.

That includes things like:

- Pods
- Deployments
- Services
- ConfigMaps
- Secrets
- Roles
- RoleBindings
- StatefulSets

If `etcd` is lost and you do not have a backup, you can lose the entire logical state of your cluster.

That is why snapshot backups are so important.

In our kubeadm lab, `etcd` runs as a static pod on `k8s-master`.

Instead of trying to run `etcdctl` inside the etcd container, in this version of the lesson we will install `etcdctl` directly on `k8s-master` and use it there.

That is a better fit for our environment because the etcd container image can be very minimal and may not contain `sh` or `bash`.

---

## What we will do

We will:

1. Inspect the kubeadm-managed `etcd` static pod.
2. Install `etcdctl` locally on `k8s-master`.
3. Create a snapshot backup with that local `etcdctl`.
4. Inspect that snapshot.
5. Restore that snapshot into a new data directory.
6. Point the kubeadm `etcd` manifest at the restored data.
7. Bring the control plane back and verify that the cluster works again.

This is a dangerous operation in a real cluster.

For this repository, treat it as a lab exercise.

---

## Prerequisites

Before doing this lesson, make sure:

1. Your kubeadm cluster is up and working.
2. You can run `kubectl` from `k8s-master`.
3. You have root access on `k8s-master`.
4. You are comfortable editing files on `k8s-master`.

We are assuming a single control plane node:

- `k8s-master`

This lesson is written for that simpler lab topology.

---

## Why etcd backups matter

When you create a Kubernetes resource, it is eventually stored in `etcd`.

The API server is the front door, but `etcd` is where the persistent cluster state lives.

That means:

- if the API server goes down temporarily, Kubernetes can still recover once it comes back
- if `etcd` data is lost, the cluster state itself is gone

So the backup target we care about is the `etcd` snapshot.

---

## Checking the etcd static pod setup

On `k8s-master`, first inspect the control plane pods:

```bash
kubectl get pods -n kube-system -o wide
```

You should see an etcd pod with a name like:

```text
etcd-k8s-master
```

Now inspect the static pod manifest:

```bash
sudo cat /etc/kubernetes/manifests/etcd.yaml
```

You should notice things like:

- the `etcd` image
- the certificate paths under `/etc/kubernetes/pki/etcd`
- the data directory, usually `/var/lib/etcd`

That is the configuration kubelet uses to keep the etcd static pod running.

---

## Installing etcdctl locally on k8s-master

We want `etcdctl` on the host itself.

On Ubuntu-based systems, the easiest option is usually the `etcd-client` package:

```bash
sudo apt-get update
sudo apt-get install -y etcd-client
```

Check that the command now exists:

```bash
ETCDCTL_API=3 etcdctl version
```

We need to specify ETCDCTL_API=3.

For this lab, what matters most is that:

- `etcdctl` is installed locally on `k8s-master`
- it can authenticate with the existing etcd certificates
- it can talk to `https://127.0.0.1:2379`

---

## Creating an etcd snapshot backup

Now create the snapshot directly from `k8s-master`:

```bash
sudo ETCDCTL_API=3 etcdctl snapshot save /home/vagrant/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

This is much more reliable in our lab than `kubectl exec`, because it does not depend on the etcd container having a shell installed.

If you want to be extra explicit, you can first verify that etcd answers locally:

```bash
sudo ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

If that reports healthy, the snapshot command should work too.

---

## Inspecting the snapshot

Now inspect the snapshot contents:

```bash
sudo ETCDCTL_API=3 etcdctl snapshot status /home/vagrant/etcd-snapshot.db -w table
```

This should show things like:

- the snapshot hash
- the revision
- the total keys
- the snapshot size

That tells us the backup is a real etcd snapshot, not just an empty file.

---

## Restoring the snapshot in a kubeadm lab

This part is the dangerous one.

We will restore the snapshot into a fresh data directory and then update the static pod manifest to use that restored directory.

### 1. Restore the snapshot to a directory

Use the locally installed `etcdctl` (this one doesn't need sudo, we don't access the key files):

```bash
ETCDCTL_API=3 etcdctl snapshot restore /home/vagrant/etcd-snapshot.db \
  --data-dir=/home/vagrant/etcd-restore \
  --name=k8s-master \
  --initial-cluster=k8s-master=https://192.168.50.10:2380 \
  --initial-advertise-peer-urls=https://192.168.50.10:2380
```

### 2. Stop the API server and etcd static pods

Move the manifests out of the kubelet manifest directory temporarily:

```bash
sudo mkdir -p /root/k8s-manifests-backup
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /root/k8s-manifests-backup/
sudo mv /etc/kubernetes/manifests/etcd.yaml /root/k8s-manifests-backup/
```

Wait a few seconds, then check that they are gone:

```bash
sudo crictl ps | grep "etcd"
```

If `crictl` is not present, you can simply wait a bit and continue.


### 3. Update the etcd manifest to use the restored data

Edit the backed-up manifest:

```bash
sudo vim /root/k8s-manifests-backup/etcd.yaml
```

Update the `hostPath` volume that points at the old etcd data directory so it points to:

```text
/home/vagrant/etcd-restore
```

This will basically mount your snapshot instead of the previous data.

---

## Bringing the control plane back up

Now move the updated etcd manifest back:

```bash
sudo mv /root/k8s-manifests-backup/etcd.yaml /etc/kubernetes/manifests/
```

Wait for etcd to come back.

You can check with:

```bash
sudo crictl ps | grep etcd
```

Then move the API server manifest back:

```bash
sudo mv /root/k8s-manifests-backup/kube-apiserver.yaml /etc/kubernetes/manifests/
```

Wait a bit, then check the control plane:

```bash
kubectl get pods -n kube-system
```

Eventually you should see:

- `etcd-k8s-master`
- `kube-apiserver-k8s-master`

running again.

---

## Verifying the restore

Now verify that the cluster responds again:

```bash
kubectl get nodes
kubectl get pods -A
```

You can also verify the etcd data directory now in use by checking:

```bash
sudo cat /etc/kubernetes/manifests/etcd.yaml
```

You should see it pointing to:

```text
/home/vagrant/etcd-restore
```

That confirms the static pod is now running from the restored snapshot data.

If you want one more check, inspect the restore directory:

```bash
sudo ls -lah /home/vagrant/etcd-restore
```

---

## Cleaning up

If you want to keep the restored setup as-is, you can leave it alone.

If you want to remove the copied snapshot file:

```bash
rm -f /home/vagrant/etcd-snapshot.db
```

If you want to remove the old manifest backup directory after you are done:

```bash
sudo rm -rf /root/k8s-manifests-backup
```

Your etcd will now continue operating, but keep its data in the `/home/vagrant/etcd-restore` folder.

You can revert it by following steps 2 and 3, but instead pointing the volume at the original location.

---

You have reached the end. Congratulations. I hope it will all be useful. :D
