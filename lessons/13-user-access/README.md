[← Back to Lessons](../../README.md#lessons)

# User access

# Table of contents

- [User access](#user-access)
- [What we will create](#what-we-will-create)
- [Prerequisites](#prerequisites)
- [The local certificate simulation](#the-local-certificate-simulation)
- [Creating a local certificate authority](#creating-a-local-certificate-authority)
- [Creating and signing a server certificate](#creating-and-signing-a-server-certificate)
- [Creating and signing a client certificate](#creating-and-signing-a-client-certificate)
- [Creating a Kubernetes user certificate request](#creating-a-kubernetes-user-certificate-request)
- [Creating a namespace-limited user in Kubernetes](#creating-a-namespace-limited-user-in-kubernetes)
- [Building a kubeconfig for the new user](#building-a-kubeconfig-for-the-new-user)
- [Testing access in the default namespace](#testing-access-in-the-default-namespace)
- [Testing access in the new namespace](#testing-access-in-the-new-namespace)
- [Refreshing kubeadm-managed control plane certificates](#refreshing-kubeadm-managed-control-plane-certificates)
- [Cleaning up](#cleaning-up)

---

## User access

In this lesson, we will look at two related ideas:

1. How certificates are signed in a simple certificate authority flow.
2. How Kubernetes can use client certificates to identify a user.

First, we will simulate a small PKI flow with:

- a certificate authority
- a server certificate
- a client certificate

Then we will use the same general idea in Kubernetes:

- create a private key for a new user
- create a CSR for that user
- ask Kubernetes to sign it
- build a kubeconfig for that user
- limit that user to a single namespace

Finally, we will test that:

- the new user can not deploy into `default`
- the new user can deploy into the namespace we explicitly allowed

---

## What we will create

We will use these folders:

- `certificate-authority/`
- `server/`
- `client/`

We will also use these files:

- `user-namespace.yaml`
- `user-role.yaml`
- `user-rolebinding.yaml`
- `kubernetes-user-csr.yaml`
- `default-test-pod.yaml`
- `student-space-test-pod.yaml`

---

## Prerequisites

Before running these examples, make sure:

1. Your Kubernetes cluster is up and working.
2. `openssl` is installed on `k8s-master`.
3. You can run `kubectl` as an admin user on `k8s-master`.
4. Your cluster is using the normal kubeadm certificate setup.

We will assume:

- the Kubernetes API server is reachable at `https://192.168.50.10:6443`
- your admin kubeconfig is in `$HOME/.kube/config`

---

## The local certificate simulation

Before we create a Kubernetes user certificate, it helps to see the basic certificate process in isolation.

We will simulate this flow:

1. Create a certificate authority private key and certificate.
2. Create a server private key and CSR.
3. Sign that CSR with the CA.
4. Create a client private key and CSR.
5. Sign that CSR with the CA.

This is not Kubernetes-specific yet.

It is just a small demo of how certificate signing works.

Go into the lesson directory:

```bash
cd /vagrant/lessons/13-user-access
```

---

## Creating a local certificate authority

Create the CA private key:

```bash
openssl genrsa -out certificate-authority/ca.key 4096
```

Create the CA certificate:

```bash
openssl req -x509 -new -nodes \
  -key certificate-authority/ca.key \
  -sha256 -days 365 \
  -out certificate-authority/ca.crt \
  -subj "/CN=demo-certificate-authority"
```

Inspect it:

```bash
openssl x509 -in certificate-authority/ca.crt -text -noout
```

At this point, our CA can sign other certificates.

---

## Creating and signing a server certificate

Create the server private key:

```bash
openssl genrsa -out server/server.key 2048
```

Create the server CSR:

```bash
openssl req -new \
  -key server/server.key \
  -out server/server.csr \
  -subj "/CN=demo-server"
```

Inspect it:

```bash
openssl req -in server/server.csr -text -noout
```

Sign the server CSR with our CA:

```bash
openssl x509 -req \
  -in server/server.csr \
  -CA certificate-authority/ca.crt \
  -CAkey certificate-authority/ca.key \
  -CAcreateserial \
  -out server/server.crt \
  -days 365 \
  -sha256
```

Inspect the signed certificate:

```bash
openssl x509 -in server/server.crt -text -noout
```

Now the server has:

- a private key
- a CSR
- a certificate signed by our CA

---

## Creating and signing a client certificate

Create the client private key:

```bash
openssl genrsa -out client/client.key 2048
```

Create the client CSR:

```bash
openssl req -new \
  -key client/client.key \
  -out client/client.csr \
  -subj "/CN=demo-client"
```

Inspect it:

```bash
openssl req -in client/client.csr -text -noout
```

Sign the client CSR with our CA:

```bash
openssl x509 -req \
  -in client/client.csr \
  -CA certificate-authority/ca.crt \
  -CAkey certificate-authority/ca.key \
  -CAcreateserial \
  -out client/client.crt \
  -days 365 \
  -sha256
```

Inspect it:

```bash
openssl x509 -in client/client.crt -text -noout
```

That is the basic idea we will now reuse in Kubernetes.

---

## The client verifying the server:

```bash
openssl verify -CAfile certificate-authority/ca.crt server/server.crt
```

---

## The server verifying the client:

```bash
openssl verify -CAfile certificate-authority/ca.crt client/client.crt
```

---

## Creating a Kubernetes user certificate request

Now we will create a real client key for a Kubernetes user.

Let us call the user:

```text
student-user
```

Generate the private key:

```bash
openssl genrsa -out client/student-user.key 2048
```

Generate the CSR:

```bash
openssl req -new \
  -key client/student-user.key \
  -out client/student-user.csr \
  -subj "/CN=student-user"
```

Convert the CSR to one line of base64 and replace "REPLACE_WITH_BASE64_CSR" in the `kubernetes-user-csr.yaml` with that base64 line:

```bash
sed -i "s|REPLACE_WITH_BASE64_CSR|$(base64 -w 0 client/student-user.csr)|" kubernetes-user-csr.yaml
```

Then create the Kubernetes CSR object:

```bash
kubectl apply -f kubernetes-user-csr.yaml
```

Check it:

```bash
kubectl get csr
kubectl describe csr student-user
```

Approve it:

```bash
kubectl certificate approve student-user
```

Extract the signed certificate:

```bash
kubectl get csr student-user -o jsonpath='{.status.certificate}' | base64 -d > client/student-user.crt
```

Inspect it:

```bash
openssl x509 -in client/student-user.crt -text -noout
```

Now we have:

- `client/student-user.key`
- `client/student-user.crt`

This is the client certificate pair for our Kubernetes user.

---

## Creating a namespace-limited user in Kubernetes

Now create the namespace:

```bash
kubectl apply -f user-namespace.yaml
```

Create the Role:

```bash
kubectl apply -f user-role.yaml
```

Create the RoleBinding:

```bash
kubectl apply -f user-rolebinding.yaml
```

Check them:

```bash
kubectl get namespace student-space
kubectl get role -n student-space
kubectl get rolebinding -n student-space
```

This grants the Kubernetes user `student-user` access only inside:

```text
student-space
```

We are not giving this user any permissions in `default`.

---

## Building a kubeconfig for the new user

Now we will build a kubeconfig that uses the new certificate.

Set the cluster entry using the actual cluster CA from kubeadm:

```bash
kubectl config set-cluster kubernetes-playground \
  --server=https://192.168.50.10:6443 \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --embed-certs=false \
  --kubeconfig=client/student-user.kubeconfig
```

Set the user entry:

```bash
kubectl config set-credentials student-user \
  --client-certificate=client/student-user.crt \
  --client-key=client/student-user.key \
  --embed-certs=false \
  --kubeconfig=client/student-user.kubeconfig
```

Set the context:

```bash
kubectl config set-context student-user-context \
  --cluster=kubernetes-playground \
  --user=student-user \
  --namespace=student-space \
  --kubeconfig=client/student-user.kubeconfig
```

Use that context:

```bash
kubectl config use-context student-user-context --kubeconfig=client/student-user.kubeconfig
```

Check it:

```bash
kubectl config get-contexts --kubeconfig=client/student-user.kubeconfig
```

---

## Testing access in the default namespace

First, try to list pods in `default` as the new user:

```bash
kubectl get pods -n default --kubeconfig=client/student-user.kubeconfig
```

This should be forbidden.

Now try to create the pod in `default`:

```bash
kubectl apply -f default-test-pod.yaml -n default --kubeconfig=client/student-user.kubeconfig
```

This should also fail.

That is exactly what we want.

The user is authenticated, but not authorized there.

---

## Testing access in the new namespace

Now try the allowed namespace:

```bash
kubectl get pods -n student-space --kubeconfig=client/student-user.kubeconfig
kubectl apply -f student-space-test-pod.yaml --kubeconfig=client/student-user.kubeconfig
```

Check it:

```bash
kubectl get pods -n student-space --kubeconfig=client/student-user.kubeconfig
```

This time it should work.

So we have successfully demonstrated:

- authentication by client certificate
- authorization by Role and RoleBinding
- namespace-limited access

---

## Refreshing kubeadm-managed control plane certificates

Since this lesson is about certificates, it is also a good place to mention how kubeadm can refresh the control plane certificates it manages.

This is a different use case from the `student-user` certificate we created earlier.

Here we are talking about kubeadm-managed cluster certificates such as:

- `apiserver`
- `apiserver-kubelet-client`
- `apiserver-etcd-client`
- `front-proxy-client`
- `admin.conf`
- `controller-manager.conf`
- `scheduler.conf`

Official kubeadm certificate reference:

- https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-certs/

### 1. Check certificate expiration

On `k8s-master`, run:

```bash
sudo kubeadm certs check-expiration
```

This shows which kubeadm-managed certificates exist and when they expire.

### 2. Renew all kubeadm-managed certificates

To renew everything kubeadm manages:

```bash
sudo kubeadm certs renew all
```

You can also renew certificates individually.

For example:

```bash
sudo kubeadm certs renew apiserver
sudo kubeadm certs renew apiserver-etcd-client
sudo kubeadm certs renew admin.conf
```

These renewals run unconditionally.

That means kubeadm does not wait until a certificate is almost expired. It simply refreshes it when you ask.

### 3. Restart the control plane static pods

After renewing the certificates, the control plane components need to pick up the new files.

Because kubeadm runs them as static pods, an easy way to restart them is to temporarily move the manifest files out of `/etc/kubernetes/manifests` and then move them back.

For example:

```bash
sudo mkdir -p /root/k8s-manifests-temp
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /root/k8s-manifests-temp/
sleep 20
sudo mv /root/k8s-manifests-temp/kube-apiserver.yaml /etc/kubernetes/manifests/
```

You can do the same for:

- `kube-controller-manager.yaml`
- `kube-scheduler.yaml`
- `etcd.yaml`

if needed.

### 4. Refresh local admin kubeconfig if needed

If you renewed `admin.conf`, update your local copy too:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 5. Verify the cluster still works

```bash
kubectl get nodes
kubectl get pods -A
```

This is a useful operational task to know even though our main user-access example in this lesson focused on namespace-limited RBAC for a human user certificate.

---

## Cleaning up

To remove the Kubernetes resources:

```bash
kubectl delete -f student-space-test-pod.yaml --ignore-not-found
kubectl delete -f user-rolebinding.yaml --ignore-not-found
kubectl delete -f user-role.yaml --ignore-not-found
kubectl delete -f user-namespace.yaml --ignore-not-found
kubectl delete csr student-user --ignore-not-found
```

If you want to remove the generated local files too:

```bash
rm -f certificate-authority/*
rm -f server/*
rm -f client/*
```

---

# [14 - Kubernetes upgrade](../14-kubernetes-upgrade/README.md)
