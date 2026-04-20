[← Back to Lessons](../../README.md#lessons)

# Kubernetes installation

# Table of contents

- [Kubernetes installation](#kubernetes-installation)
- [Prerequisites](#prerequisites)
  - [Make sure the MAC addresses of your devices and product_uuid are different](#make-sure-the-mac-addresses-of-your-devices-and-product_uuid-are-different)
  - [Check that the ports Kubernetes uses are not already in use](#check-that-the-ports-kubernetes-uses-are-not-already-in-use)
  - [Make sure swap is off](#make-sure-swap-is-off)
  - [Load br_netfilter module on all machines](#load-br_netfilter-module-on-all-machines)
  - [Enable IP forwarding on all machines](#enable-ip-forwarding-on-all-machines)
- [Installing container runtime, kubelet, kubeadm and kubectl](#installing-container-runtime-kubelet-kubeadm-and-kubectl)
- [Adding an insecure registry in cri-o](#adding-an-insecure-registry-in-cri-o)
- [Bootstrapping a cluster](#bootstrapping-a-cluster)
- [Getting the other nodes to join our cluster](#getting-the-other-nodes-to-join-our-cluster)
- [The networking plugin](#the-networking-plugin)

---

## Kubernetes installation

In this lesson, we will install Kubernetes v1.35.0, using the kubeadm utility.

We aren't picking the latest minor version so that we can show a kubernetes upgrade later.

Documentation:

https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/


---

## Prerequisites

---

### Make sure the MAC addresses of your devices and product_uuid are different

MAC addresses can be checked with:

```bash
ip link
```

We care about the enp0s8 network. We already gave them each different MACs in the Vagrantfile.

product_uuids can be checked with:

```bash
sudo cat /sys/class/dmi/id/product_uuid
```

This will most likely also be different.

---

### Check that the ports Kubernetes uses are not already in use

These are the ports it uses: https://kubernetes.io/docs/reference/networking/ports-and-protocols/

They can be checked with the netcat command:

```bash
nc 127.0.0.1 6443 -zv -w 2
```

In our example, they shouldn't be taken by anything to start with.

---

### Make sure swap is off

Swap is a mechanism that allows Linux to supplement its RAM memory with disk space by storing the least frequently used items in RAM on the disk.

Kubernetes works by assuming our nodes have a fixed, limited amount of RAM that can be used, it won't let us start more containers if there are not enough resources.

Swap also slows things down.

In our case, it should be disabled to start with. To check:

```bash
swapon --show
```

If it shows nothing, you're good.

In case swap was on (not our case), you would have to:

```bash
sudo swapoff -a
```

And to make it persist across reboots:

```bash
sudo vim /etc/fstab
```

And you would have to find a line like `/swap.img none swap sw 0 0` and comment it out by adding a `#` at the beginning.

Again, **not needed for our example**.

---

### Load br_netfilter module on all machines

This is a Linux kernel module that allows iptables rules to process traffic passing through network bridges.

The components of Kubernetes that handle the networking between containers need it.

IPtables rules are basically some rules that can be set on a machine that say what should happen to network packets going through a machine.

As we will see, Kubernetes elements work with them to do a lot of networking things in the background.

So, we will enable the **br_netfilter** module.

We can check that it is not loaded with:

```bash
lsmod | grep br_netfilter
```

If nothing pops up, it is not properly loaded.

To load it:

```bash
sudo modprobe br_netfilter
```

To make sure it is loaded after restarts as well:

```bash
echo br_netfilter | sudo tee /etc/modules-load.d/k8s.conf
```

**You need to do this on all 3 machines.**

After this, your can check if it is enabled again.

Your output should be:

```bash
vagrant@k8s-master:~$ lsmod | grep br_netfilter
br_netfilter           32768  0
bridge                311296  1 br_netfilter
```

---

### Enable IP forwarding on all machines

You might remember this one from our container networking deep dive lesson.

This allows our machines to forward packets.

We can check if it's enabled with:

```bash
sysctl net.ipv4.ip_forward
```

If disabled, it will return 0.

It might be 1 because we enabled it in our previous examples.

To enable it if not enabled:
```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

To make it persist across reboots:

```bash
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-kubernetes-ip-forward.conf
```

To have it apply immediately from this configuration we wrote (shouldn't be needed, we already turned it on manually):

```bash
sudo sysctl --system
```

---

## Installing container runtime, kubelet, kubeadm and kubectl

Kubernetes doesn't run containers by itself, it just tells a container runtime to do it.

The one we will be using is Cri-O, simply because most other tutorials install containerd :)

The instructions to install Cri-o are here:

https://github.com/cri-o/packaging/blob/main/README.md#usage

I will also provide instructions here as I will not install the latest version in order for us to be able to upgrade it during a lesson.

I will install both cri-o, the kubeadm utility, the kubelet and the kubectl command line at the same time.

**We will do these steps on all 3 machines.**

First export these variables:

```bash
KUBERNETES_VERSION=v1.35
CRIO_VERSION=v1.35
```

We need these dependencies installed first:
```bash
sudo apt-get update
sudo apt-get install -y software-properties-common curl
```

Then add the Kubernetes repository to apt:

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key |
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" |
    sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Then add the cri-o repository:

```bash
curl -fsSL https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key |
    sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/ /" |
    sudo tee /etc/apt/sources.list.d/cri-o.list
```

Then refresh apt-get:
```bash
sudo apt-get update
```

We can now check the available versions of the things we want to install:
```bash
echo "cri-o versions:"
sudo apt-cache madison cri-o
echo "kubelet versions:"
sudo apt-cache madison kubelet
echo "kubeadm versions:"
sudo apt-cache madison kubeadm
echo "kubectl versions:"
sudo apt-cache madison kubectl
```

We want to pick the 1.35.0 version of each so that we can later upgrade it.

So, we have to run the following on all 3 machines:

```bash
sudo apt-get install -y \
  cri-o=1.35.0-1.1 \
  kubelet=1.35.0-1.1 \
  kubeadm=1.35.0-1.1 \
  kubectl=1.35.0-1.1
```

Now we have container runtimes, the kubelets which will tell the container runtimes what to run for us, the kubectl which is our way to talk to kubernetes and kubeadm which will install the other components of Kubernetes for us.

---

## Adding an insecure registry in cri-o

We previously made our own nexus registry, but it doesn't use https.

We will need to tell cri-o that it is an allowed insecure registry, just like we told Docker.

In order to do that, we have to edit this file:

```bash
sudo vim /etc/containers/registries.conf
```

And make it look like this:

```bash
[[registry]]
location = "k8s-master:8082"
insecure = true
```

**Do it on all 3 nodes.**

An easy command to do it in one line is:

```bash
echo -e "[[registry]]\nlocation = \"k8s-master:8082\"\ninsecure = true" | sudo tee /etc/containers/registries.conf > /dev/null
```

After this restart cri-o on all 3 machines so that it can apply this configuration:

```bash
sudo systemctl restart crio
```

That should be it.

---

## Bootstrapping a cluster.

Now, to actually bootstrap the kubernetes cluster, on **k8s-master** only, we run:

```bash
sudo kubeadm init \
--kubernetes-version=1.35.0 \
--apiserver-advertise-address=192.168.50.10 \
--pod-network-cidr=10.244.0.0/16 \
--cri-socket=unix:///var/run/crio/crio.sock
```

We set **--kubernetes-version=1.35.0** because otherwise, it would automatically pull the latest one.

We set **apiserver-advertise-address** because our machines have multiple network interfaces and all, we tell it on which interface's IP the kube-api-server should listen.

This is that IP binding stuff again.

The **pod-network-cidr** is the subnet our pods IPs will be created in. It will be 10.244.something.something.

We need to specify **cri-socket** here because we have both cri-o and containerd installed. Containerd came with Docker. We could technically just use it alongside with Docker, but for the sake of experimenting with multiple things, we will use cri-o.

At the end, we will get a bunch of instructions.

First one that we need to run is:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

This one basically copies the admin credentials for accessing Kubernetes to our local user so that we can use the kubectl commands.

We will talk more about this later.

The second instruction will be something like:

```bash
kubeadm join 192.168.50.10:6443 --token ost22e.52uch830sdr1x6z1 \
        --discovery-token-ca-cert-hash sha256:5f4505861c8ac19f0310ed46feec3037fc3b7a18ae3173024a15525d57b35bdd
```

A different such token will be generated for you so, **please, note down the command it shows you, you can not use the example I provided,** we will need to run it on the other computers that we want to add to the cluster.

---

## Getting the other nodes to join our cluster

Go and run the command you copied with your token on **k8s-worker-1**.

You will have to run it as root so, add a `sudo` before the command. It should look like:

```bash
sudo kubeadm join 192.168.50.10:6443 --token ost22e.52uch830sdr1x6z1 \
        --discovery-token-ca-cert-hash sha256:5f4505861c8ac19f0310ed46feec3037fc3b7a18ae3173024a15525d57b35bdd
```

After this process finishes, on **k8s-master-1**, you can actually see that your node joined:

```bash
kubectl get pods
```

Your output will look something like this:

```bash
vagrant@k8s-master:~$ kubectl get nodes
NAME           STATUS     ROLES           AGE     VERSION
k8s-master     NotReady   control-plane   7m49s   v1.35.0
k8s-worker-1   NotReady   <none>          35s     v1.35.0
```

Do not worry about the fact that they are not ready yet. We will deal with that later.

Go run the join command on **k8s-worker-2** now.

After that is done, you should see all 3 nodes on **k8s-master**

```bash
vagrant@k8s-master:~$ kubectl get nodes
NAME           STATUS     ROLES           AGE     VERSION
k8s-master     NotReady   control-plane   14m     v1.35.0
k8s-worker-1   NotReady   <none>          6m55s   v1.35.0
k8s-worker-2   NotReady   <none>          9s      v1.35.0
```

---

## The networking plugin

We saw that Kubernetes can use both containerd and crio.

This is because both tools have the same purpose, running containers, and also both tools can speak a language called CRI, or Container Runtime Interface.

This was done so that different tools can be developed by third party developers which fulfill different functionalities.

Kubernetes can talk to them if they implement this Container Runtime Interface specification.

Kubernetes has many such interfaces defined, so that 3rd party tools can handle multiple functionalities.

One such interface is CNI or container network interface.

Remember that stuff we did in the networking deep dive chapter?

There are different tools that can do that in Kubernetes. They all have different functionalities, like encrypting our traffic and other things.

Such tools are called container network plugins.

There are quite a few of them. Here is a list https://kubernetes.io/docs/concepts/cluster-administration/addons/#networking-and-network-policy

For our example, we will install one called **Calico**.

We will install it using something called the Tigera operator.

An operator is an external tool that can manage Kubernetes for us. It can run inside Kubernetes.

In a way, it works similarly to the kube-controller-manager.

We will install this operator and define some new types of resources that this operator will be able to use.

We will deploy them straight from their site.

Here is their procedure: https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart

I will also provide our own procedure. We need to run it a bit differently so that the CNI plugin knows the IP range of our pods that we defined earlier.

Run this on `k8s-master`:

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/tigera-operator.yaml
```

All kubernetes resources are difined using yaml files. We will see examples later.

Now, we basically installed the definitions of some custom resources. Think of them as classes.

We will also have to instantiate them so that the Tigera operator has something to work with. Think of it like creating objects based on a class.

But we will need to take their example and modify it a bit. We will download it instead of applying it directly:

```bash
cd ~
mkdir calico
cd calico
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/custom-resources.yaml
```

Then, in this file, we need to change their default `cidr: 192.168.0.0/16` with the network we picked during **kubeadm init**, `cidr: 10.244.0.0/16`.

To easily do this:

```bash
sed -i 's/192\.168\.0\.0\/16/10.244.0.0\/16/' custom-resources.yaml
```

Then, to apply this file:

```bash
kubectl create -f custom-resources.yaml
```

We can see all the things that the Tiger operator will run on our cluster using

```bash
kubectl get pods -A
```

We need to wait for all of them to be running.

The -A notation lets us see things in all namespaces.

Usually, we only view our direct workloads. There are different systems working in the background that we do not necessarily need to see. These are placed in different namespaces. Think of namespaces like different rooms in a house.

We usually look at one namespace at a time.

Now, after everything says running, we can see that our cluster's nodes are marked as ready:

```bash
vagrant@k8s-master:~/calico$ kubectl get nodes
NAME           STATUS   ROLES           AGE   VERSION
k8s-master     Ready    control-plane   40m   v1.35.0
k8s-worker-1   Ready    <none>          33m   v1.35.0
k8s-worker-2   Ready    <none>          26m   v1.35.0
```

---

Congratulations! You just installed your first kubernetes cluster!

Let's quickly make our command line have autocomplete for kubectl and also alias k to kubectl:

https://kubernetes.io/docs/reference/kubectl/quick-reference/

```bash
source <(kubectl completion bash) # set up autocomplete in bash into the current shell, bash-completion package should be installed first.
echo "source <(kubectl completion bash)" >> ~/.bashrc # add autocomplete permanently to your bash shell.
alias k=kubectl # alias k to kubectl
complete -o default -F __start_kubectl k # give k autocomplete too
echo -e '\nalias k=kubectl\ncomplete -o default -F __start_kubectl k' >> ~/.bashrc # make it persist across reboots
```

We will see how we can use it in the next lessons.

---

# [04 - First Pods](../04-first-pods/README.md)


