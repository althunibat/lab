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


#===============================================================================
# Templates
#===============================================================================

# Hosts Manager first
data "template_file" "manager-first" {
    template = "${file("templates/hosts.tpl")}"
    vars {
    hostname = "${var.sw_node_prefix}-manager-0"
    host_ip  = "${lookup(var.sw_manager_ips, 0)}"
  }
}

# Hosts Managers
data "template_file" "managers" {
    count    = "${length(var.sw_manager_ips) - 1}"
    template = "${file("templates/hosts.tpl")}"
 
    vars {
    hostname = "${var.sw_node_prefix}-manager-${count.index + 1}"
    host_ip  = "${lookup(var.sw_manager_ips, count.index + 1)}"
  }
}

# Hosts workers

data "template_file" "workers" {
    count    = "${length(var.sw_worker_ips)}"
    template = "${file("templates/hosts.tpl")}"
 
    vars {
    hostname = "${var.sw_node_prefix}-worker-${count.index}"
    host_ip  = "${lookup(var.sw_worker_ips, count.index)}"
  }
}

data "template_file" "docker-swarm" {
    template = "${file("templates/docker-swarm.tpl")}"
    vars {
    manager-1 = "${var.sw_node_prefix}-manager-0"
  }
}

# HAProxy template #
data "template_file" "haproxy" {
  template = "${file("templates/haproxy.tpl")}"

  vars {
    bind_ip = "${var.sw_haproxy_ip}"
  }
}

# HAProxy server backend template for portainer #
data "template_file" "haproxy_backend_sw" {
  count    = "${length(var.sw_manager_ips)}"
  template = "${file("templates/haproxy.backend.tpl")}"

  vars {
    prefix_server     = "${var.sw_node_prefix}"
    backend_server_ip = "${lookup(var.sw_manager_ips, count.index)}"
    count             = "${count.index}"
    port             = "9000"
  }
}

# HAProxy server backend template for portainer #
data "template_file" "haproxy_backend_consul" {
  count    = "${length(var.sw_manager_ips)}"
  template = "${file("templates/haproxy.backend.tpl")}"

  vars {
    prefix_server     = "${var.sw_node_prefix}"
    backend_server_ip = "${lookup(var.sw_manager_ips, count.index)}"
    count             = "${count.index}"
    port             = "8500"
  }
}

# HAProxy server backend template for api-gw #
data "template_file" "haproxy_backend_api" {
  count    = "${length(var.sw_worker_ips)}"
  template = "${file("templates/haproxy.backend.tpl")}"

  vars {
    prefix_server     = "${var.sw_node_prefix}"
    backend_server_ip = "${lookup(var.sw_worker_ips, count.index)}"
    count             = "${count.index}"
    port             = "9999"
  }
}

# HAProxy server backend template for api-gw #
data "template_file" "haproxy_backend_api_admin" {
  count    = "${length(var.sw_worker_ips)}"
  template = "${file("templates/haproxy.backend.tpl")}"

  vars {
    prefix_server     = "${var.sw_node_prefix}"
    backend_server_ip = "${lookup(var.sw_worker_ips, count.index)}"
    count             = "${count.index}"
    port             = "9998"
  }
}

#===============================================================================
# Local Resources
#===============================================================================

# Create Hosts.ini from terraform template
resource "local_file" "ansible_hosts" {
  content  = "[manager-first]\n${data.template_file.manager-first.rendered}\n[managers]\n${join("", data.template_file.managers.*.rendered)}\n[workers]\n${join("", data.template_file.workers.*.rendered)}"
  filename = "ansible/hosts.ini"
}

resource "local_file" "ansible_docker_swarm" {
  content  = "${data.template_file.docker-swarm.rendered}"
  filename = "ansible/docker-swarm.yml"
}


resource "local_file" "haproxy_cfg" {
  content  = "${data.template_file.haproxy.rendered}\nbackend sw-cluster\n\tmode\thttp\n\tbalance\troundrobin\n\t${join("", data.template_file.haproxy_backend_sw.*.rendered)}\nbackend consul-cluster\n\tmode\thttp\n\tbalance\troundrobin\n\t${join("", data.template_file.haproxy_backend_consul.*.rendered)}\nbackend api-cluster\n\tmode\thttp\n\tbalance\troundrobin\n\t${join("", data.template_file.haproxy_backend_api.*.rendered)}\nbackend api-admin-cluster\n\tmode\thttp\n\tbalance\troundrobin\n\t${join("", data.template_file.haproxy_backend_api_admin.*.rendered)}"
  filename = "assets/haproxy.cfg"
}

#===============================================================================
# Null Resources
#===============================================================================

resource "null_resource" "create_swarm" {
  provisioner "local-exec" {
    command = "cd ansible && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini -b -u ${var.vm_user} -v docker-swarm.yml"
  }
   depends_on = ["vsphere_virtual_machine.workers", "local_file.ansible_hosts","null_resource.create_swarm"]
}

resource "null_resource" "install_portainer" {
  connection {
    type        = "ssh"
    user        = "${var.vm_user}"
    host        = "${lookup(var.sw_manager_ips, 0)}"
    private_key = "${file("${var.vm_ssh_private_key}")}"
  }

  provisioner "file" {
    source      = "assets/portainer-agent-stack.yml"
    destination = "/tmp/portainer-agent-stack.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "docker volume create --driver=vsphere --name=portainer_data@ds-1 -o size=100mb",
      "docker stack deploy --compose-file=/tmp/portainer-agent-stack.yml portainer"
    ]
  }

  depends_on = ["null_resource.create_swarm"]
}

resource "null_resource" "install_consul_bootstrap" {
  connection {
    type        = "ssh"
    user        = "${var.vm_user}"
    host        = "${lookup(var.sw_manager_ips, 0)}"
    private_key = "${file("${var.vm_ssh_private_key}")}"
  }

  provisioner "remote-exec" {
    inline = [
      "docker pull consul:1.4.0",
      "docker run -d --name=consul --net=host consul:1.4.0 agent -server -bind=${lookup(var.sw_manager_ips, 0)} -bootstrap -ui -client=0.0.0.0"
    ]
  }

  depends_on = ["null_resource.install_portainer"]
}

resource "null_resource" "install_consul_servers" {
  count    = "${length(var.sw_manager_ips) - 1}"
  connection {
    type        = "ssh"
    user        = "${var.vm_user}"
    host        = "${lookup(var.sw_manager_ips, count.index + 1)}"
    private_key = "${file("${var.vm_ssh_private_key}")}"
  }

  provisioner "remote-exec" {
    inline = [
      "docker pull consul:1.4.0",
      "docker run -d --name=consul --net=host consul:1.4.0 agent -server -bind=${lookup(var.sw_manager_ips, count.index + 1)} -retry-join=${lookup(var.sw_manager_ips, 0)}  -bootstrap-expect=3 -ui -client=0.0.0.0"
    ]
  }

  depends_on = ["null_resource.install_consul_bootstrap"]
}

resource "null_resource" "finish_swarm_agents" {
  count    = "${length(var.sw_worker_ips)}"
  connection {
    type        = "ssh"
    user        = "${var.vm_user}"
    host        = "${lookup(var.sw_worker_ips, count.index)}"
    private_key = "${file("${var.vm_ssh_private_key}")}"
  }

  provisioner "remote-exec" {
    inline = [
      "docker pull consul:1.4.0",
      "docker pull gliderlabs/registrator",
      "docker pull fabiolb/fabio",
      "docker run -d --name=consul --net=host consul:1.4.0 agent -bind=${lookup(var.sw_worker_ips, count.index)} -retry-join=${lookup(var.sw_manager_ips, 0)} -client=0.0.0.0",
      "docker run -d --name=registrator --net=host --volume=/var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator:latest -cleanup=true -deregister=always -ip='${lookup(var.sw_worker_ips, count.index)}' consul:http://${lookup(var.sw_worker_ips, count.index)}:8500",
      "docker run -d --name=fabio --net=host -e 'registry_consul_addr=${lookup(var.sw_worker_ips, count.index)}:8500' fabiolb/fabio"
    ]
  }

  depends_on = ["null_resource.install_consul_servers"]
}