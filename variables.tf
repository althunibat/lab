#====================#
# vCenter connection #
#====================#

variable "vsphere_user" {
  description = "vSphere user name"
}

variable "vsphere_password" {
  description = "vSphere password"
}

variable "vsphere_vcenter" {
  description = "vCenter server FQDN or IP"
}

variable "vsphere_unverified_ssl" {
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


variable "vsphere_enable_anti_affinity" {
  description = "Enable anti affinity between manager VMs and between worker VMs (DRS need to be enable on the cluster)"
  default     = "true"
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

variable "sw_manager_ips" {
  type        = "map"
  description = "IPs used for the Swarm manager nodes"
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
