# Kubernetes playground

Greetings and welcome to my humble teaching project.

This project's purpose is to help you install your very own Kubernetes cluster.

It is designed to give you the easiest possible way to spin up a real Kubernetes cluster (not Minikube or something that installs in one command and gives no explanations).

This project is paired with my Udemy course (currently a work in progress).

Together with the course, this project will teach you Kubernetes in a very in-depth and easy-to-follow way.

By the end, you will understand what everything does intuitively, not just "install this, do that" :)

---

# Table of Contents

- [Prerequisites](#prerequisites)
  - [Visual Studio Code](#visual-studio-code)
  - [Git](#git)
  - [VirtualBox](#virtualbox)
  - [Vagrant](#vagrant)
  - [PuTTY](#putty)
  - [WinSCP](#winscp)
  - [SuperPuTTY](#superputty)
  - [SSH Keys](#ssh-keys)

# Prerequisites

## Visual Studio Code

It's optional, however, I highly recommend having this, it's a useful editor for all sorts of code. Definitely useful in DevOps where you often deal with many different types of files working together :)

Download and install from:
```
https://code.visualstudio.com/download
```

## Git

Download and install Git from:

```
https://git-scm.com/install/windows
```

In the screen where it asks you what editor to use, pick **Visual Studio Code**.

It is also **VERY IMPORTANT** that you set **Checkout as-is, commit as-is** when it gets to the "Configuring line ending conversions" step. This ensures that, when your git downloads a .sh script meant for Linux, it will not replace its line endings (a hidden character that signifies a newline) with a Windows-specific one. This can cause the Linux script to fail.

More info here on the topic: https://www.cs.toronto.edu/~krueger/csc209h/tut/line-endings.html#:~:text=Text%20files%20created%20on%20DOS/Windows%20machines%20have,sure%20the%20line%20endings%20are%20translated%20properly.

The rest is a matter of next -> next -> install -> finish.

You might already have this, you need it to clone the project :)

In case you don't and you don't know what that means, to clone the project using Git, open a PowerShell in the folder where you want this project and run:

```
git clone https://github.com/mihai-scornea/kubernetes-playground.git
```

## VirtualBox

VirtualBox is a hypervisor, a program used to simulate hardware and run virtual machines. We will use this to create virtual computers that we will treat as computers sitting somewhere in a room, on which we will install our Kubernetes cluster.

Download and install from:
```
https://www.virtualbox.org/wiki/Downloads
```

## Vagrant

Vagrant is a utility program that can tell VirtualBox what to do for us.

Vagrant can read a special file called a Vagrantfile in which we can describe exactly what virtual machines we want. Very helpful so that you don't have to manually create them, do their networking, etc.

Download and install from:
```
https://developer.hashicorp.com/vagrant/install
```

## PuTTY

PuTTY is a program that helps us form SSH connections to other machines. We will use it to access our virtual machines.

Download and install PuTTY from:
```
https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html
```

## WinSCP

WinSCP is a file manager that allows you to copy files to and from a remote machine. Useful so you don’t have to deal with SCP commands directly or PuTTY's `pscp` command.

Download and install WinSCP from:
```
https://winscp.net/eng/download.php
```

## SuperPuTTY

SuperPuTTY is a window manager for PuTTY. In simple terms, we can imagine a PuTTY connection as being a tab in a browser and SuperPuTTY is the entire browser, where you can have multiple tabs, bookmarks, settings and more. It is very useful for managing Kubernetes clusters as these can involve a lot of machines (10+) and having them neatly accessible makes a world of difference.

Download and install from:

```
https://superputty.org/
```

On first launch, it will ask you to provide it some paths. You can give it `putty.exe` and `pscp.exe` from the PuTTY installation folder, probably `C:\Program Files\PuTTY`.

Also WinSCP.exe from the WinSCP installation folder, probably `C:\Program Files (x86)\WinSCP`.

Then, you're good to go!

## SSH keys

### ⚠️ WARNING: The SSH keys in this repository are for demo purposes only.

### Do NOT use them in real environments.

These keys are public in this repository and should be treated as compromised.

I included them to make it easier for you to run this project without dealing with SSH setup initially, but I will not reuse them in any actual non-learning project and neither should you.

In order to generate some yourself, you will need a Linux shell.

You can use **Git bash**, just right click in the project folder, on empty space in windows explorer -> show more options -> open git bash here.

Then, enter the following:

```bash
ssh-keygen -t ed25519 -f ssh-key/id_rsa
```

It will generate you a key pair of "id_rsa" and "id_rsa.pub".

In order to also use them with SuperPuTTY, you need to convert the private key to the .ppk format.

Luckily, PuTTY comes with an utility called PuTTYgen.

You can simply open it, click "Load" and select your **id_rsa** private key. After that, click ok, give it a comment if you want and click "Save private key", save it in the ssh-key folder in here (or wherever you want, you'll need to import it yourself in pageant, it is explained lower on the page).

Bonus hint: On Windows, press Windows + . to open the emoji menu.

That's how I put that warning sign without looking it up in a browser 🪽

# TO DO:

The rest of the project :D