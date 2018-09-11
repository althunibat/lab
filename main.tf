#===============================================================================
# vSphere Provider
#===============================================================================

provider "vsphere" {
  version        = "1.7.0"
  vsphere_server = "${var.vsphere_vcenter}"
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  allow_unverified_ssl = "${var.vsphere_unverified_ssl}"
}

#===============================================================================
# vSphere Data
#===============================================================================

data "vsphere_datacenter" "dc" {
  name = "${var.vsphere_datacenter}"
}

data "vsphere_compute_cluster" "cluster" {
  name          = "${var.vsphere_drs_cluster}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_resource_pool" "pool" {
  name          = "${var.vsphere_resource_pool}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_datastore_cluster" "datastore_cluster" {
  name          = "${var.vm_datastore}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "${var.vm_network}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${var.vm_template}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}


#===============================================================================
# vSphere Resources
#===============================================================================

resource "vsphere_virtual_machine" "manager" {
  count            = "${length(var.sw_manager_ips)}"
  name             = "${var.sw_node_prefix}-manager-${count.index}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_cluster_id = "${data.vsphere_datastore_cluster.datastore_cluster.id}"

  num_cpus = "${var.sw_manager_cpu}"
  memory   = "${var.sw_manager_ram}"
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "${var.sw_node_prefix}-manager-${count.index}.vmdk"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    linked_clone  = "${var.vm_linked_clone}"

    customize {
      linux_options {
        host_name = "${var.sw_node_prefix}-manager-${count.index}"
        domain    = "${var.lab_domain}"
      }

      network_interface {
        ipv4_address = "${lookup(var.sw_manager_ips, count.index)}"
        ipv4_netmask = "${var.lab_netmask}"
      }

      ipv4_gateway    = "${var.lab_gateway}"
      dns_server_list = ["${var.lab_dns}"]
    }
  }
   provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = "${var.vm_user}"
      private_key = "${file("${var.vm_ssh_private_key}")}"
     }
 
     inline = [
       "yum install -y yum-utils device-mapper-persistent-data lvm2",
       "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo",
       "yum install -y docker-ce",
       "mkdir /etc/docker && mv /tmp/docker-daemon.json /etc/docker/daemon.json",
       "echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.conf",
       "echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.conf",
       "systemctl daemon-reload",
       "systemctl enable docker",
       "systemctl start docker",
       "usermod -aG docker ${var.vm_user}",
     ]
   }
}

resource "vsphere_compute_cluster_vm_anti_affinity_rule" "manager_anti_affinity_rule" {
  count               = "${var.vsphere_enable_anti_affinity == "true" ? 1 : 0}"
  name                = "${var.sw_node_prefix}-manager-anti-affinity-rule"
  compute_cluster_id  = "${data.vsphere_compute_cluster.cluster.id}"
  virtual_machine_ids = ["${vsphere_virtual_machine.manager.*.id}"]
}

resource "vsphere_datastore_cluster_vm_anti_affinity_rule" "manager_vm_anti_affinity_rule" {
  count               = "${var.vsphere_enable_anti_affinity == "true" ? 1 : 0}"
  name                 = "${var.sw_node_prefix}-manager-vm-anti-affinity-rule"
  datastore_cluster_id = "${data.vsphere_datastore_cluster.datastore_cluster.id}"
  virtual_machine_ids  = ["${vsphere_virtual_machine.manager.*.id}"]
}

resource "vsphere_virtual_machine" "worker" {
  count            = "${length(var.sw_worker_ips)}"
  name             = "${var.sw_node_prefix}-worker-${count.index}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_cluster_id = "${data.vsphere_datastore_cluster.datastore_cluster.id}"

  num_cpus = "${var.sw_worker_cpu}"
  memory   = "${var.sw_worker_ram}"
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "${var.sw_node_prefix}-worker-${count.index}.vmdk"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    linked_clone  = "${var.vm_linked_clone}"

    customize {
      linux_options {
        host_name = "${var.sw_node_prefix}-worker-${count.index}"
        domain    = "${var.lab_domain}"
      }

      network_interface {
        ipv4_address = "${lookup(var.sw_worker_ips, count.index)}"
        ipv4_netmask = "${var.lab_netmask}"
      }

      ipv4_gateway    = "${var.lab_gateway}"
      dns_server_list = ["${var.lab_dns}"]
    }
  }

   provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = "${var.vm_user}"
      private_key = "${file("${var.vm_ssh_private_key}")}"
     }
 
     inline = [
       "yum install -y yum-utils device-mapper-persistent-data lvm2",
       "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo",
       "yum install -y docker-ce",
       "mkdir /etc/docker && mv /tmp/docker-daemon.json /etc/docker/daemon.json",
       "echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.conf",
       "echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.conf",
       "systemctl daemon-reload",
       "systemctl enable docker",
       "systemctl start docker",
       "usermod -aG docker ${var.vm_user}",
     ]
   }
   depends_on = ["vsphere_datastore_cluster_vm_anti_affinity_rule.manager_vm_anti_affinity_rule","vsphere_compute_cluster_vm_anti_affinity_rule.manager_anti_affinity_rule"]
}

resource "vsphere_compute_cluster_vm_anti_affinity_rule" "worker_anti_affinity_rule" {
  count               = "${var.vsphere_enable_anti_affinity == "true" ? 1 : 0}"
  name                = "${var.sw_node_prefix}-worker-anti-affinity-rule"
  compute_cluster_id  = "${data.vsphere_compute_cluster.cluster.id}"
  virtual_machine_ids = ["${vsphere_virtual_machine.worker.*.id}"]
}

resource "vsphere_datastore_cluster_vm_anti_affinity_rule" "worker_vm_anti_affinity_rule" {
  count               = "${var.vsphere_enable_anti_affinity == "true" ? 1 : 0}"
  name                 = "${var.sw_node_prefix}-worker-vm-anti-affinity-rule"
  datastore_cluster_id = "${data.vsphere_datastore_cluster.datastore_cluster.id}"
  virtual_machine_ids  = ["${vsphere_virtual_machine.worker.*.id}"]
}

resource "null_resource" "create_swarm" {
  provisioner "local-exec"{
    command = "cd ansible && ansible-playbook -i hosts.ini -b -u ${var.vm_user} -v docker-swarm.yml"
  }

  depends_on =["vsphere_compute_cluster_vm_anti_affinity_rule.worker_anti_affinity_rule","vsphere_datastore_cluster_vm_anti_affinity_rule.worker_vm_anti_affinity_rule"]
}
