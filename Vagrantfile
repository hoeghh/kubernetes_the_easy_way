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
  puts "__Etcd ___________"
  puts "| - Nodes  : #{etcd_c}"
  puts "| - CPU    : #{etcd_cpu}"
  puts "| - Memory : #{etcd_mem}"
  puts " "
  puts "__Masters ________"
  puts "| - Nodes  : #{master_c}"
  puts "| - CPU    : #{master_cpu}"
  puts "| - Memory : #{master_mem}"
  puts " "
  puts "__Workers ________"
  puts "| - Nodes  : #{worker_c}"
  puts "| - CPU    : #{worker_cpu}"
  puts "| - Memory : #{worker_mem}"
  puts " "
  puts "__Loadbalancers __"
  puts "| - Nodes  : #{loadbalancer_c}"
  puts "| - CPU    : #{loadbalancer_cpu}"
  puts "| - Memory : #{loadbalancer_mem}"
  puts " "

Vagrant.configure("2") do |config|
  config.vm.boot_timeout = 500
  config.vm.box = "bento/centos-7.4"
  config.vm.network "private_network", type: "dhcp"
  config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"

  # Copying host-file to every host
  config.vm.provision "file", source: "output/hosts", destination: "/tmp/hosts"

  # Provitioning ETCD nodes
  (1 .. etcd_c). each do |etcds|
    etcd_name = "k8s-etcd-#{etcds}"
    config.vm.define etcd_name do |etcd|
      config.vm.provider "virtualbox" do |vb_etcd|
        vb_etcd.name = "K8s-Etcd-#{etcds}"
        vb_etcd.cpus = etcd_cpu
        vb_etcd.gui = false
        vb_etcd.linked_clone = true
        vb_etcd.memory = etcd_mem
        vb_etcd.customize ["modifyvm", :id, "--cableconnected1", "on"]
      end
      etcd.vm.network "private_network", ip: "192.168.50.#{etcds + 10}"
      etcd.vm.hostname = etcd_name
      etcd.vm.provision :shell, inline: "sed 's/127\.0\.0\.1.*.*/192\.168\.50\.#{etcds + 10} k8s-etcd-#{etcds}/' -i /etc/hosts"

      # Copying hosts file to host
      etcd.vm.provision "file", source: "output/hosts",                  destination: "/tmp/hosts"

      # Copying certificates to host
      etcd.vm.provision "file", source: "ssl/kubernetes.pem",     destination: "/tmp/kubernetes.pem"
      etcd.vm.provision "file", source: "ssl/kubernetes-key.pem", destination: "/tmp/kubernetes-key.pem"
      etcd.vm.provision "file", source: "ssl/ca.pem",             destination: "/tmp/ca.pem"

      # Running install script
      etcd.vm.provision "shell", path: "./scripts/install-etcd.sh"
    end
  end

  # Provitioning MASTER nodes
  (1 .. master_c). each do |masters|
    master_name = "k8s-master-#{masters}"
    config.vm.define master_name do |master|
      config.vm.provider "virtualbox" do |vb_master|
        vb_master.name = "K8s-Master-#{masters}"
        vb_master.cpus = master_cpu
        vb_master.gui = false
        vb_master.linked_clone = true
        vb_master.memory = master_mem
        vb_master.customize ["modifyvm", :id, "--cableconnected1", "on"]
      end
      master.vm.network "private_network", ip: "192.168.50.#{masters + 20}"
      master.vm.hostname = master_name
      master.vm.provision :shell, inline: "sed 's/127\.0\.0\.1.*.*/192\.168\.50\.#{masters + 20} k8s-master-#{masters}/' -i /etc/hosts"

      # Copying hosts file to host
      master.vm.provision "file", source: "output/hosts", destination: "/tmp/hosts"

      # Copying data encryption key and config to master nodes
      master.vm.provision "file", source: "output/encryption-config.yaml", destination: "/tmp/encryption-config.yaml"

      # Copying certificates to host
      master.vm.provision "file", source: "ssl/kubernetes.pem",     destination: "/tmp/kubernetes.pem"
      master.vm.provision "file", source: "ssl/kubernetes-key.pem", destination: "/tmp/kubernetes-key.pem"
      master.vm.provision "file", source: "ssl/ca.pem",             destination: "/tmp/ca.pem"
      master.vm.provision "file", source: "ssl/ca-key.pem",             destination: "/tmp/ca-key.pem"

      # Running install script
      master.vm.provision "shell", path: "./scripts/install-master.sh"
    end
  end

  # Provitioning WORKER nodes
  (1 .. worker_c). each do |workers|
    worker_name = "k8s-worker-#{workers}"
    config.vm.define worker_name do |worker|
      config.vm.provider "virtualbox" do |vb_worker|
        vb_worker.name = "K8s-Worker-#{workers}"
        vb_worker.cpus = worker_cpu
        vb_worker.gui = false
        vb_worker.linked_clone = true
        vb_worker.memory = worker_mem
        vb_worker.customize ["modifyvm", :id, "--cableconnected1", "on"]
      end
      worker.vm.network "private_network", ip: "192.168.50.#{workers + 30}"
      worker.vm.hostname = worker_name
      worker.vm.provision :shell, inline: "sed 's/127\.0\.0\.1.*.*/192\.168\.50\.#{workers + 30} k8s-worker-#{workers}/' -i /etc/hosts"

      # Copying hosts file to host
      worker.vm.provision "file", source: "output/hosts", destination: "/tmp/hosts"

      # Copying config files for authentication of kubelet and kube-proxy
      worker.vm.provision "file", source: "output/k8s-worker-#{workers}.kubeconfig", destination: "/tmp/k8s-worker-#{workers}.kubeconfig"
      worker.vm.provision "file", source: "output/kube-proxy.kubeconfig", destination: "/tmp/kube-proxy.kubeconfig"

      # Running install script
      worker.vm.provision "shell", path: "./scripts/install-worker.sh"
    end
  end

  # Provitioning LOADBALANCER nodes
  (1 .. loadbalancer_c). each do |loadbalancers|
    loadbalancer_name = "k8s-loadbalancer-#{loadbalancers}"
    config.vm.define loadbalancer_name do |loadbalancer|
      config.vm.provider "virtualbox" do |vb_loadbalancer|
        vb_loadbalancer.name = "K8s-Loadbalancer-#{loadbalancers}"
        vb_loadbalancer.cpus = loadbalancer_cpu
        vb_loadbalancer.gui = false
        vb_loadbalancer.linked_clone = true
        vb_loadbalancer.memory = loadbalancer_mem
        vb_loadbalancer.customize ["modifyvm", :id, "--cableconnected1", "on"]
      end
      loadbalancer.vm.network "private_network", ip: "192.168.50.#{loadbalancers + 4}"
      loadbalancer.vm.hostname = loadbalancer_name
      loadbalancer.vm.provision :shell, inline: "sed 's/127\.0\.0\.1.*.*/192\.168\.50\.#{loadbalancers + 4} k8s-loadbalancer-#{loadbalancers}/' -i /etc/hosts"

      # Copying hosts file to host
      loadbalancer.vm.provision "file", source: "output/hosts", destination: "/tmp/hosts"

      # Running install script
      loadbalancer.vm.provision "shell", path: "./scripts/install-loadbalancer.sh"
    end
  end


end


