# vagrant up
# install python:
# vagrant ssh ;  sudo apt-get update && sudo apt-get install python-dev python-pip -q -y
Vagrant.configure("2") do |config|

  # machine.vm.provision "shell",
  #    inline: "sudo apt-get update && sudo apt-get install python-dev python-pip -q -y"

  config.vm.provision "ansible" do |ansible|
    ansible.verbose = "v"
    ansible.playbook = "site.yml"
    
    ansible.groups = {
          "worker" => ["jenkins-worker-publisher"],
          "publisher" => ["jenkins-worker-publisher"],
          "master" => ["jenkins-master"]
        }
  end
  
  config.vm.define "jenkins-master" do |machine|
    machine.vm.hostname = "jenkins-master"
    machine.vm.network "private_network", ip: "192.168.77.20"
    machine.vm.box = "debian/stretch64"
    machine.vm.synced_folder ".", "/vagrant", disabled: true

    machine.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = 4096
      vb.cpus = 2
    end
  end
  
  config.vm.define "jenkins-worker-publisher" do |machine|
    machine.vm.hostname = "jenkins-worker-publisher"
    machine.vm.network "private_network", ip: "192.168.77.30"
    machine.vm.box = "debian/stretch64"
    machine.vm.synced_folder ".", "/vagrant", disabled: true

    machine.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = 1024
      vb.cpus = 1
    end
  end

end
