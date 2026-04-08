Vagrant.configure("2") do |config|

    # VM configuration
    # Adjust the memory and CPU settings as needed
    # Minimum requirements for Kubernetes cluster: 2GB RAM and 2 CPUs per node
    # Current settings take up about 12GB of RAM and 6 CPUs in total
    # If you have just 16GB of ram, you can try reducing the memory to 
    # 3GB per node (vm_memory = 3072) to save some resources and still have a functional cluster
    vm_memory = 4096
    vm_cpus = 2

    # A script that will run on the initial "vagrant up" command, setting our nodes up as we want them to be.
    # If we use "vagrant halt", then "vagrant up" again, the script will not run again, so we won't have to worry about it messing with our setup.
    # Still, I wrote it to be idempotent, meaning that if it runs multiple times, it won't cause any issues or duplicate entries in the /etc/hosts file 
    # or the SSH keys setup. I did this as a learning exercise :)
    # The provisioning step can be explicitly called with "vagrant provision" with the machines running or "vagrant up --provision" when the machines are halted.
    def provision_script(node_name)
        # Host entries to allow communication between nodes using hostnames
        host_entries = <<-SHELL
            # Add entries to /etc/hosts for cluster nodes if they don't already exist
            # The trick with "grep -q" is used to check if the entry already exists in the /etc/hosts file before adding it, preventing duplicate entries.
            # The || operator is a logical OR that allows the echo command to run only if the grep command does not find the specified hostname in the /etc/hosts file.
            # Such an operator stops running subsequent commands if the previous command succeeds, because for "OR", only one has to be true.
            grep -q "k8s-master" /etc/hosts || echo "192.168.50.10 k8s-master" | sudo tee -a /etc/hosts
            grep -q "k8s-worker-1" /etc/hosts || echo "192.168.50.11 k8s-worker-1" | sudo tee -a /etc/hosts
            grep -q "k8s-worker-2" /etc/hosts || echo "192.168.50.12 k8s-worker-2" | sudo tee -a /etc/hosts
        SHELL

        # Script to provision SSH keys for passwordless SSH access between nodes
        # and also from the host machine to the nodes
        ssh_key_provision = <<-SHELL
            # Create the .ssh directory if it doesn't exist
            # This directory is used both to store the public key that the system uses
            # to validate the private key used by incoming SSH connections.

            # The .ssh folder also stores the private key that will be used by the vagrant
            # user to connect to other nodes in the cluster without needing a password.
            mkdir -p /home/vagrant/.ssh

            # Copy the private key from the shared folder to the .ssh directory in the vagrant user's home directory.
            # Everything in the folder where the Vagrantfile is located is shared with the VM at the /vagrant path (not the /home/vagrant path).
            # Copying the private key allows the vagrant user to use it for SSH authentication when connecting to other nodes in the cluster
            # That have the matching public key in their authorized_keys file.
            # A similar trick to "grep -q" is used to check if the private key already exists in the .ssh directory before copying it,
            # preventing unnecessary copying and potential overwriting of existing keys. The -f option checks if the file exists and is a regular file.
            # The [ ... ] block is a fancier way to run the "test" command. A way to see its output is to run it then do "echo $?" right after.
            [ -f /home/vagrant/.ssh/id_rsa ] || cp /vagrant/ssh-key/id_rsa /home/vagrant/.ssh/id_rsa

            # Append the public key to the authorized_keys file to allow passwordless SSH access to the node itself
            # using the corresponding private key.
            # Same trick with "grep -q" is used to check if the public key is already present in the authorized_keys file before appending it, preventing duplicate entries.
            # The 2>/dev/null part is used to suppress error messages in case the authorized_keys file doesn't exist yet, which can happen on the first run.
            grep -q "$(cat /vagrant/ssh-key/id_rsa.pub)" /home/vagrant/.ssh/authorized_keys 2>/dev/null || \
            cat /vagrant/ssh-key/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys

            # Set the correct permissions for the .ssh directory and its contents to ensure that SSH works properly.
            chown -R vagrant:vagrant /home/vagrant/.ssh
            chmod 600 /home/vagrant/.ssh/id_rsa
            chmod 600 /home/vagrant/.ssh/authorized_keys
            # The .ssh directory uses 700 (rwx) because directories need execute (x) permission to be accessed.
            # Without execute (like in 600), you can't enter the directory or read files inside it.
            chmod 700 /home/vagrant/.ssh
        SHELL

        # Here we set the hostname of the node using the hostnamectl command.
        # This changes the "something" in "vagrant@something" in your shell prompt to the actual node name (like "k8s-master" or "k8s-worker-1").
        # After that, it runs the host entries script to ensure that the /etc/hosts file is properly configured for inter-node communication, 
        # and then it runs the SSH key provisioning script to set up passwordless SSH access.
        "sudo hostnamectl set-hostname #{node_name}\n" + host_entries + ssh_key_provision
    end
    
    # Define the virtual machines for the master and worker nodes.
    # Master node
    config.vm.define "k8s-master" do |master|

        # Specify the image to use for the master node. ubuntu/jammy64 is a popular Ubuntu 22.04 LTS image available on Vagrant Cloud
        master.vm.box = "ubuntu/jammy64"

        # Port 2222 on the host machine will be forwarded to port 22 (SSH) on the master node, allowing us to SSH into
        # the master node from our host machine using "ssh -p 2222 vagrant@localhost" or using PuTTY to connect to localhost:2222.
        master.vm.network "forwarded_port", guest: 22, host: 2222

        # Assign a static private IP and MAC address to the master node so it can be reliably reached by other nodes.
        # The MAC address must be unique per VM to avoid network conflicts.
        # The NIC type (82540EM) is widely supported and avoids driver issues in Linux.
        # The forwarded port is used for SSH from the host, while the private network IP is used for communication between nodes.
        # We use port forwarding for SSH instead of the private IP because it is more reliable on Windows systems.
        master.vm.network "private_network", ip: "192.168.50.10", mac: "080027AABB01", nic_type: "82540EM"
        
        # Increase boot timeout to 10 minutes to avoid failures on slower machines.
        # Extra tip: If you also have Hyper-V enabled and your VMs hang during boot, try either disabling Hyper-V
        # or opening up virtualbox and staring at the "preview" window of the machine, it will "wake it up" :)
        master.vm.boot_timeout = 600

        # Specifying the name of the VM in VirtualBox, as well as its memory and CPU allocation.
        master.vm.provider "virtualbox" do |vb|
            vb.name = "k8s-master"
            vb.memory = vm_memory
            vb.cpus = vm_cpus
        end

        # Specify the provisioning script to run on the master node. This script will set up the hostname, 
        # configure the /etc/hosts file, and set up SSH keys for passwordless access.
        # Provisioning runs once on initial 'vagrant up' unless explicitly re-run.
        master.vm.provision "shell", inline: provision_script("k8s-master")

        # Waits up to 5 minutes during "vagrant halt" before forcefully shutting down the machine in case it doesn't stop.
        master.vm.graceful_halt_timeout = 300
    end

    # Worker node 1
    config.vm.define "k8s-worker-1" do |worker|
        worker.vm.box = "ubuntu/jammy64"
        worker.vm.network "forwarded_port", guest: 22, host: 2223
        worker.vm.network "private_network", ip: "192.168.50.11", mac: "080027AABB02", nic_type: "82540EM"
        worker.vm.boot_timeout = 600

        worker.vm.provider "virtualbox" do |vb|
            vb.name = "k8s-worker-1"
            vb.memory = vm_memory
            vb.cpus = vm_cpus
        end

        worker.vm.provision "shell", inline: provision_script("k8s-worker-1")
        worker.vm.graceful_halt_timeout = 300
    end

    # Worker node 2
    config.vm.define "k8s-worker-2" do |worker|
        worker.vm.box = "ubuntu/jammy64"
        worker.vm.network "forwarded_port", guest: 22, host: 2224
        worker.vm.network "private_network", ip: "192.168.50.12", mac: "080027AABB03", nic_type: "82540EM"
        worker.vm.boot_timeout = 600

        worker.vm.provider "virtualbox" do |vb|
            vb.name = "k8s-worker-2"
            vb.memory = vm_memory
            vb.cpus = vm_cpus
        end

        worker.vm.provision "shell", inline: provision_script("k8s-worker-2")
        worker.vm.graceful_halt_timeout = 300
    end

end
