# -*- mode: ruby -*-
# # vi: set ft=ruby :

ENV['VAGRANT_DEFAULT_PROVIDER'] = 'virtualbox'

  etcd_c           = ENV['ETCD_COUNT'].to_i
  etcd_cpu         = ENV['ETCD_CPU'].to_i
  etcd_mem         = ENV['ETCD_MEM'].to_i

  master_c         = ENV['MASTER_COUNT'].to_i
  master_cpu       = ENV['MASTER_CPU'].to_i
  master_mem       = ENV['MASTER_MEM'].to_i

  worker_c         = ENV['WORKER_COUNT'].to_i
  worker_cpu       = ENV['WORKER_CPU'].to_i
  worker_mem       = ENV['WORKER_MEM'].to_i

  loadbalancer_c   = ENV['LOADBALANCER_COUNT'].to_i
  loadbalancer_cpu = ENV['LOADBALANCER_CPU'].to_i
  loadbalancer_mem = ENV['LOADBALANCER_MEM'].to_i

  puts " "
  puts "Etcd _____________"
  puts "   - Nodes  : #{etcd_c}"
  puts "   - CPU    : #{etcd_cpu}"
  puts "   - Memory : #{etcd_mem}"
  puts " "
  puts "Masters __________"
  puts "   - Nodes  : #{master_c}"
  puts "   - CPU    : #{master_cpu}"
  puts "   - Memory : #{master_mem}"
  puts " "
  puts "Workers __________"
  puts "   - Nodes  : #{worker_c}"
  puts "   - CPU    : #{worker_cpu}"
  puts "   - Memory : #{worker_mem}"
  puts " "
  puts "Loadbalancers ____"
  puts "   - Nodes  : #{loadbalancer_c}"
  puts "   - CPU    : #{loadbalancer_cpu}"
  puts "   - Memory : #{loadbalancer_mem}"
  puts " "

# Provitioning etcd nodes
Vagrant.configure("2") do |config|
  config.vm.boot_timeout = 500
  config.vm.box = "bento/ubuntu-16.04"
  config.vm.network "private_network", type: "dhcp"
  config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"

  # Provitioning ETCD nodes
  (1 .. etcd_c). each do |etcds|
    etcd_name = "k8s-etcd-#{etcds}"
    config.vm.define etcd_name do |etcd|
      config.vm.provider "virtualbox" do |vb_etcd|
        vb_etcd.cpus = etcd_cpu
        vb_etcd.gui = false
        vb_etcd.linked_clone = true
        vb_etcd.memory = etcd_mem
        vb_etcd.customize ["modifyvm", :id, "--cableconnected1", "on"]
      end
      etcd.vm.network "private_network", ip: "192.168.10.#{etcds + 10}"
      etcd.vm.hostname = etcd_name
      etcd.vm.provision :shell, inline: "sed 's/127\.0\.0\.1.*.*/192\.168\.50\.#{etcds + 10} k8s-etcd-#{etcds}/' -i /etc/hosts"
      etcd.vm.provision "shell", path: "./scripts/install-etcd.sh"
    end
  end

  # Provitioning MASTER nodes
  (1 .. master_c). each do |masters|
    master_name = "k8s-master-#{masters}"
    config.vm.define master_name do |master|
      config.vm.provider "virtualbox" do |vb_master|
        vb_master.cpus = master_cpu
        vb_master.gui = false
        vb_master.linked_clone = true
        vb_master.memory = master_mem
        vb_master.customize ["modifyvm", :id, "--cableconnected1", "on"]
      end
      master.vm.network "private_network", ip: "192.168.20.#{masters + 20}"
      master.vm.hostname = master_name
      master.vm.provision :shell, inline: "sed 's/127\.0\.0\.1.*.*/192\.168\.50\.#{masters + 20} k8s-master-#{masters}/' -i /etc/hosts"
      master.vm.provision "shell", path: "./scripts/install-master.sh"
    end
  end

end


