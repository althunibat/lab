variable "vcenter_user" {
  description = "vCenter user name"
}

variable "vcenter_password" {
  description = "vSphere password"
}

variable "vcenter_server" {
  description = "vCenter server FQDN or IP"
}

variable "vcenter_unverified_ssl" {
  description = "Is the vCenter using a self signed certificate (true/false)"
}

variable "vsphere_datacenter" {
  description = "vSphere datacenter"
}

variable "vsphere_drs_cluster" {
  description = "vSphere cluster"
  default     = ""
}

variable "vsphere_resource_pool" {
  description = "vSphere resource pool"
}


variable "vm_user" {
  description = "SSH user for the vSphere virtual machines"
}

variable "vm_ssh_private_key" {
  description = "SSH private key path for the vSphere virtual machines"
}

variable "vm_datastore" {
  description = "Datastore used for the vSphere virtual machines"
}

variable "vm_network" {
  description = "Private Network used for the vSphere virtual machines"
}

variable "vm_template" {
  description = "Template used to create the vSphere virtual machines"
}

variable "vm_linked_clone" {
  description = "Use linked clone to create the vSphere virtual machines from the template (true/false). If you would like to use the linked clone feature, your template need to have one and only one snapshot"
  default = "false"
}

variable "sw_jaeger_ip" {
  description = "IP used for jaeger node"
}

variable "sw_jaeger_cpu" {
  description = "Number of vCPU for for jaeger VM"
}

variable "sw_jaeger_ram" {
  description = "Amount of RAM for for jaeger VM"
}

variable "sw_haproxy_ip" {
  description = "IP used for haproxy node"
}

variable "sw_haproxy_cpu" {
  description = "Number of vCPU for for haproxy VM"
}

variable "sw_haproxy_ram" {
  description = "Amount of RAM for for haproxy VM"
}
variable "sw_manager_ips" {
  type        = "map"
  description = "IPs used for other Swarm manager nodes"
}

variable "sw_worker_ips" {
  type        = "map"
  description = "IPs used for the Swarm worker nodes"
}
variable "lab_netmask" {
  description = "Netmask used for the Lab (example: 24)"
}

variable "lab_gateway" {
  description = "Gateway for the lab nodes"
}

variable "lab_dns" {
  description = "DNS for the lab nodes"
}

variable "lab_domain" {
  description = "Domain for the lab nodes"
}

variable "sw_manager_cpu" {
  description = "Number of vCPU for the Swarm manager virtual machines"
}

variable "sw_manager_ram" {
  description = "Amount of RAM for the Swarm manager virtual machines (example: 2048)"
}

variable "sw_worker_cpu" {
  description = "Number of vCPU for the Swarm worker virtual machines"
}

variable "sw_worker_ram" {
  description = "Amount of RAM for the Swarm worker virtual machines (example: 2048)"
}

variable "sw_node_prefix" {
  description = "Prefix for the name of the virtual machines and the hostname of the Swarm nodes"
}


variable "sw_elk_ips" {
  type        = "map"
  description = "IPs used for ELK nodes"
}
variable "sw_elk_cpu" {
  description = "Number of vCPU for the ELK virtual machines"
}

variable "sw_elk_ram" {
  description = "Amount of RAM for the ELK virtual machines (example: 2048)"
}
