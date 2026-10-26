# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "ubuntu/jammy64"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  # config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Disable the default share of the current code directory. Doing this
  # provides improved isolation between the vagrant box and your host
  # by making sure your Vagrantfile isn't accessible to the vagrant box.
  # If you use this you may want to enable additional shared subfolders as
  # shown above.
  # config.vm.synced_folder ".", "/vagrant", disabled: true

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Enable provisioning with a shell script. Additional provisioners such as
  # Ansible, Chef, Docker, Puppet and Salt are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL

  # ------------------------------------------------------------
  # Homework configuration
  # ------------------------------------------------------------

  # First load balancer
  config.vm.define "lb-01" do |lb|
    lb.vm.hostname = "lb-01"

    lb.vm.network "private_network",
      ip: "192.168.56.10",
      netmask: "255.255.255.0"

    lb.vm.provider "virtualbox" do |vb|
      vb.name = "ha-react-lb-01"
      vb.memory = 512
      vb.cpus = 1
      vb.gui = false
    end
  end

  # Second load balancer
  config.vm.define "lb-02" do |lb|
    lb.vm.hostname = "lb-02"

    lb.vm.network "private_network",
      ip: "192.168.56.11",
      netmask: "255.255.255.0"

    lb.vm.provider "virtualbox" do |vb|
      vb.name = "ha-react-lb-02"
      vb.memory = 512
      vb.cpus = 1
      vb.gui = false
    end
  end

  # First React web server
  config.vm.define "web-01" do |web|
    web.vm.hostname = "web-01"

    web.vm.network "private_network",
      ip: "192.168.56.20",
      netmask: "255.255.255.0"

    web.vm.provider "virtualbox" do |vb|
      vb.name = "ha-react-web-01"
      vb.memory = 1024
      vb.cpus = 1
      vb.gui = false
      # Work around the observed warm-reboot clock/boot hang on this host.
      vb.customize ["modifyvm", :id, "--paravirt-provider", "minimal"]
    end
  end

  # Second React web server
  config.vm.define "web-02" do |web|
    web.vm.hostname = "web-02"

    web.vm.network "private_network",
      ip: "192.168.56.21",
      netmask: "255.255.255.0"

    web.vm.provider "virtualbox" do |vb|
      vb.name = "ha-react-web-02"
      vb.memory = 1024
      vb.cpus = 1
      vb.gui = false
    end
  end

  # Install basic tools on every VM.
  config.vm.provision "shell", path: "scripts/provision.sh"

  # Check only this lab's host-only DHCP conflict before starting VMs.
  config.trigger.before :up do |trigger|
    trigger.name = "Prepare lab host-only network"
    trigger.run = { path: File.join(__dir__, "scripts", "prepare-host.sh") }
  end

  # Keepalived will manage the floating IP 192.168.56.100 later.
  # Do not assign that address to a VM here.
end
