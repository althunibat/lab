#===============================================================================
# vSphere Provider
#===============================================================================

provider "vsphere" {
  version              = "1.9.1"
  vsphere_server       = "${var.vcenter_server}"
  user                 = "${var.vcenter_user}"
  password             = "${var.vcenter_password}"
  allow_unverified_ssl = "${var.vcenter_unverified_ssl}"
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

resource "vsphere_virtual_machine" "managers" {
  count                = "${length(var.sw_manager_ips)}"
  name                 = "${var.sw_node_prefix}-manager-${count.index}"
  resource_pool_id     = "${data.vsphere_resource_pool.pool.id}"
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
  depends_on = ["local_file.haproxy_cfg","local_file.ansible_docker_swarm","local_file.ansible_hosts"]
}

resource "vsphere_virtual_machine" "workers" {
  count                = "${length(var.sw_worker_ips)}"
  name                 = "${var.sw_node_prefix}-worker-${count.index}"
  resource_pool_id     = "${data.vsphere_resource_pool.pool.id}"
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
     depends_on = ["vsphere_virtual_machine.managers"]
}

# Create the HAProxy load balancer VM #
resource "vsphere_virtual_machine" "haproxy" {
  name                 = "${var.sw_node_prefix}-haproxy"
  resource_pool_id     = "${data.vsphere_resource_pool.pool.id}"
  datastore_cluster_id = "${data.vsphere_datastore_cluster.datastore_cluster.id}"
  num_cpus = "${var.sw_haproxy_cpu}"
  memory   = "${var.sw_haproxy_ram}"
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"
  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }
  disk {
    label            = "${var.sw_node_prefix}-haproxy.vmdk"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    linked_clone  = "${var.vm_linked_clone}"
    customize {
      linux_options {
        host_name = "${var.sw_node_prefix}-haproxy"
        domain    = "${var.lab_domain}"
      }
      network_interface {
        ipv4_address = "${var.sw_haproxy_ip}"
        ipv4_netmask = "${var.lab_netmask}"
      }
      ipv4_gateway    = "${var.lab_gateway}"
      dns_server_list = ["${var.lab_dns}"]
    }
  }
       depends_on = ["vsphere_virtual_machine.elk"]
}

resource "vsphere_virtual_machine" "elk" {
  count                = "${length(var.sw_elk_ips)}"
  name                 = "${var.sw_node_prefix}-elk-${count.index}"
  resource_pool_id     = "${data.vsphere_resource_pool.pool.id}"
  datastore_cluster_id = "${data.vsphere_datastore_cluster.datastore_cluster.id}"

  num_cpus = "${var.sw_elk_cpu}"
  memory   = "${var.sw_elk_ram}"
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "${var.sw_node_prefix}-elk-${count.index}.vmdk"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    linked_clone  = "${var.vm_linked_clone}"

    customize {
      linux_options {
        host_name = "${var.sw_node_prefix}-elk-${count.index}"
        domain    = "${var.lab_domain}"
      }

      network_interface {
        ipv4_address = "${lookup(var.sw_elk_ips, count.index)}"
        ipv4_netmask = "${var.lab_netmask}"
      }

      ipv4_gateway    = "${var.lab_gateway}"
      dns_server_list = ["${var.lab_dns}"]
    }
  }
    provisioner "remote-exec" {
    connection {
    type        = "ssh"
    user        = "${var.vm_user}"
    host        = "${lookup(var.sw_elk_ips, count.index)}"
    private_key = "${file("${var.vm_ssh_private_key}")}"
  }
    inline = [
      "echo 'vm.max_map_count=262144' > /etc/sysctl.conf",
      "sysctl -w vm.max_map_count=262144"
    ]
  }
  depends_on = ["vsphere_virtual_machine.workers"]
}


# Create the jaeger VM #
resource "vsphere_virtual_machine" "jaeger" {
  name                 = "${var.sw_node_prefix}-jaeger"
  resource_pool_id     = "${data.vsphere_resource_pool.pool.id}"
  datastore_cluster_id = "${data.vsphere_datastore_cluster.datastore_cluster.id}"
  num_cpus = "${var.sw_jaeger_cpu}"
  memory   = "${var.sw_jaeger_ram}"
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"
  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }
  disk {
    label            = "${var.sw_node_prefix}-jaeger.vmdk"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    linked_clone  = "${var.vm_linked_clone}"
    customize {
      linux_options {
        host_name = "${var.sw_node_prefix}-jaeger"
        domain    = "${var.lab_domain}"
      }
      network_interface {
        ipv4_address = "${var.sw_jaeger_ip}"
        ipv4_netmask = "${var.lab_netmask}"
      }
      ipv4_gateway    = "${var.lab_gateway}"
      dns_server_list = ["${var.lab_dns}"]
    }
  }

 depends_on = ["vsphere_virtual_machine.elk"]
}


# Create the jaeger VM #
resource "vsphere_virtual_machine" "prometheus" {
  name                 = "${var.sw_node_prefix}-prometheus"
  resource_pool_id     = "${data.vsphere_resource_pool.pool.id}"
  datastore_cluster_id = "${data.vsphere_datastore_cluster.datastore_cluster.id}"
  num_cpus = "${var.sw_prometheus_cpu}"
  memory   = "${var.sw_prometheus_ram}"
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"
  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }
  disk {
    label            = "${var.sw_node_prefix}-prometheus.vmdk"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    linked_clone  = "${var.vm_linked_clone}"
    customize {
      linux_options {
        host_name = "${var.sw_node_prefix}-prometheus"
        domain    = "${var.lab_domain}"
      }
      network_interface {
        ipv4_address = "${var.sw_prometheus_ip}"
        ipv4_netmask = "${var.lab_netmask}"
      }
      ipv4_gateway    = "${var.lab_gateway}"
      dns_server_list = ["${var.lab_dns}"]
    }
  }

 depends_on = ["vsphere_virtual_machine.elk"]
}
