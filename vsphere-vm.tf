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

#===============================================================
# Docker Provider
#===============================================================

provider "docker" {
  host = "tcp://${var.vm_ip}:2375/"
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

#==========================================
# Docker Data
#==========================================

data "docker_registry_image" "nginx" {
  name = "nginx:alpine"
}

#===============================================================================
# vSphere Resources
#===============================================================================

resource "vsphere_virtual_machine" "testvm" {
  name             = "${var.vm_name}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_cluster_id = "${data.vsphere_datastore_cluster.datastore_cluster.id}"

  num_cpus = "${var.vm_cpu}"
  memory   = "${var.vm_ram}"
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "${var.vm_name}.vmdk"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    linked_clone  = "${var.vm_linked_clone}"

    customize {
      linux_options {
        host_name = "${var.vm_hostname}"
        domain    = "${var.lab_domain}"
      }

      network_interface {
        ipv4_address = "${var.vm_ip}"
        ipv4_netmask = "${var.lab_netmask}"
      }

      ipv4_gateway    = "${var.lab_gateway}"
      dns_server_list = ["${var.lab_dns}"]
    }
  }
  provisioner "file" {
    connection {
      type     = "ssh"
      user     = "${var.vm_user}"
      password = "${var.vm_password}"
    }

    source      = "files/docker-daemon.json"
    destination = "/tmp/docker-daemon.json"
  }

   provisioner "file" {
    connection {
      type     = "ssh"
      user     = "${var.vm_user}"
      password = "${var.vm_password}"
    }

    source      = "files/startup_options.conf"
    destination = "/tmp/startup_options.conf"
  }

   provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = "${var.vm_user}"
      password = "${var.vm_password}"
    }

    inline = [
      "yum install -y yum-utils device-mapper-persistent-data lvm2",
      "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo",
      "yum install -y docker-ce",
      "mkdir /etc/docker && mv /tmp/docker-daemon.json /etc/docker/daemon.json",
      "mkdir /etc/systemd/system/docker.service.d/ && mv /tmp/startup_options.conf /etc/systemd/system/docker.service.d/",
      "echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.conf",
      "echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.conf",
      "systemctl daemon-reload",
      "systemctl enable docker",
      "systemctl start docker",
      "usermod -aG docker ${var.vm_user}",
    ]
  }
}

#===============================================================================
# Docker Resources
#===============================================================================

resource "docker_image" "nginx" {
  name          = "${data.docker_registry_image.nginx.name}"
  pull_triggers = ["${data.docker_registry_image.nginx.sha256_digest}"]
}

resource "docker_container" "nginx" {
  name= "nginx"
  image = "${docker_image.nginx.name}"
  ports {
    internal = "80"
    external = "80"
  }
  depends_on = ["vsphere_virtual_machine.testvm"]
}
