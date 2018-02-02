# vagrant up
# install python:
# vagrant ssh ;  sudo apt-get update && sudo apt-get install python-dev python-pip -q -y
Vagrant.configure("2") do |config|

  config.vm.define "jenkins-master" do |machine|
    machine.vm.hostname = "jenkins-master"
    machine.vm.network "private_network", ip: "192.168.77.20"

    # The most common configuration options are documented and commented below.
    # For a complete reference, please see the online documentation at
    # https://docs.vagrantup.com.

    # Every Vagrant development environment requires a box. You can search for
    # boxes at https://vagrantcloud.com/search.
    machine.vm.box = "ubuntu/xenial64"

    # Create a private network, which allows host-only access to the machine
    # using a specific IP.
    machine.vm.network "private_network", ip: "192.168.33.10"

    # Share an additional folder to the guest VM. The first argument is
    # the path on the host to the actual folder. The second argument is
    # the path on the guest to mount the folder. And the optional third
    # argument is a set of non-required options.
    # machine.vm.synced_folder "../data", "/vagrant_data"

    machine.vm.provider "virtualbox" do |vb|
      vb.gui = true
      vb.memory = 4096
      vb.cpus = 2
    end

    machine.vm.provision "ansible" do |ansible|
      ansible.verbose = "v"
      ansible.playbook = "site.yml"
      ansible.ask_vault_pass = true
    end

  end

end
