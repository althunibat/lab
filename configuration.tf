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

# HAProxy server backend template for consul #
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
   depends_on = ["vsphere_virtual_machine.workers"]
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
      "docker volume create --driver=vsphere --name=portainer_db@ds-1 -o size=100mb",
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
      "docker run -d  --restart=always  --name=consul --net=host consul:1.4.0 agent -server -bind=${lookup(var.sw_manager_ips, 0)} -bootstrap -ui -client=0.0.0.0"
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
      "docker run -d  --restart=always  --name=consul --net=host consul:1.4.0 agent -server -bind=${lookup(var.sw_manager_ips, count.index + 1)} -retry-join=${lookup(var.sw_manager_ips, 0)}  -bootstrap-expect=3 -ui -client=0.0.0.0"
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
      "docker run -d  --restart=always  --name=consul --net=host consul:1.4.0 agent -bind=${lookup(var.sw_worker_ips, count.index)} -retry-join=${lookup(var.sw_manager_ips, 0)} -client=0.0.0.0",
      "docker run -d  --restart=always  --name=registrator --net=host --volume=/var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator:latest -cleanup=true -deregister=always -ip='${lookup(var.sw_worker_ips, count.index)}' consul:http://${lookup(var.sw_worker_ips, count.index)}:8500",
      "docker run -d  --restart=always  --name=fabio --net=host -e 'registry_consul_addr=${lookup(var.sw_worker_ips, count.index)}:8500' fabiolb/fabio"
    ]
  }

  depends_on = ["null_resource.install_consul_servers"]
}


resource "null_resource" "install_haproxy" {
  connection {
     type        = "ssh"
     user        = "${var.vm_user}"
     host        = "${var.sw_haproxy_ip}"
     private_key = "${file("${var.vm_ssh_private_key}")}"
    }
  
   provisioner "remote-exec" {
    inline = [
      "mkdir -p /mnt/haproxy/"
    ]
  }

   provisioner "file" {
    source      = "assets/haproxy.cfg"
    destination = "/mnt/haproxy/haproxy.cfg"
  }
   provisioner "file" {
    source      = "assets/localdomain.key.pem"
    destination = "/mnt/haproxy/localdomain.key.pem"
  }
  provisioner "remote-exec" {
    inline = [
      "docker pull haproxy:alpine",
      "docker run -d --restart=always --name haproxy --net=host -v /mnt/haproxy:/usr/local/etc/haproxy:ro haproxy:alpine"
    ]
  }
    depends_on = ["null_resource.finish_swarm_agents","vsphere_virtual_machine.haproxy"]
}

resource "null_resource" "install_zipkin" {
 connection {
     type        = "ssh"
     user        = "${var.vm_user}"
     host        = "${var.sw_zipkin_ip}"
     private_key = "${file("${var.vm_ssh_private_key}")}"
    }
 provisioner "remote-exec" {
    inline = [
      "docker pull openzipkin/zipkin-ui",
      "docker pull openzipkin/zipkin-mysql",
      "docker pull openzipkin/zipkin",
      "docker pull openzipkin/zipkin-dependencies",
      "docker run -d --restart=always --name zipkin-ui --net=host -e ZIPKIN_BASE_URL=http://${var.sw_zipkin_ip}:9411 openzipkin/zipkin-ui",
      "docker run -d --restart=always --name mysql  --net=host  openzipkin/zipkin-mysql",
      "docker run -d --restart=always --name zipkin  --net=host -e  STORAGE_TYPE=mysql -e  MYSQL_HOST=${var.sw_zipkin_ip} openzipkin/zipkin",
      "docker run -d --restart=always --name dependencies  --net=host -e  STORAGE_TYPE=mysql -e  MYSQL_HOST=${var.sw_zipkin_ip} -e MYSQL_USER=zipkin -e MYSQL_PASS=zipkin openzipkin/zipkin-dependencies",
    ]
  } 
      depends_on = ["vsphere_virtual_machine.zipkin"]
}
