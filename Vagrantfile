Vagrant.configure("2") do |config|

  config.vm.box = "debian/bullseye64"

  config.vm.define "JMMartinBBDD" do |app|
    app.vm.hostname = "JMMartinBBDD"
    app.vm.network "private_network", ip: "192.168.60.10", virtualbox_intnet: "red_BBDD"
    app.vm.provision "shell", path: "BBDD.sh"
  end

  config.vm.define "JMMartinNFS" do |app|
    app.vm.hostname = "JMMartinNFS"
    app.vm.network "private_network", ip: "192.168.56.12", virtualbox_intnet: "red1"
    app.vm.network "private_network", ip: "192.168.60.13", virtualbox_intnet: "red_BBDD"
    app.vm.provision "shell", path: "nfs.sh"
  end

  config.vm.define "JMMartinWEB1" do |app|
    app.vm.hostname = "JMMartinWEB1"
    app.vm.network "private_network", ip: "192.168.56.10", virtualbox_intnet: "red1"
    app.vm.network "private_network", ip: "192.168.60.11", virtualbox_intnet: "red_BBDD"
    app.vm.provision "shell", path: "webs.sh"
  end

  config.vm.define "JMMartinWEB2" do |app|
    app.vm.hostname = "JMMartinWEB2"
    app.vm.network "private_network", ip: "192.168.56.11", virtualbox_intnet: "red1"
    app.vm.network "private_network", ip: "192.168.60.12", virtualbox_intnet: "red_BDDD"
    app.vm.provision "shell", path: "webs.sh"
  end

  config.vm.define "JMMartinBAL" do |app|
    app.vm.hostname = "JMMartinBAL"
    app.vm.network "public_network"
    app.vm.network "private_network", ip: "192.168.56.1", virtualbox_intnet: "red1"
    app.vm.provision "shell", path: "balanceador.sh"
  end 
end
