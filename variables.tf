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


variable "vm_user" {
  description = "SSH user for the vSphere virtual machines"
}

variable "vm_password" {
  description = "SSH password for the vSphere virtual machines"
}

variable "vm_datastore" {
  description = "Datastore used for the vSphere virtual machines"
}

variable "vm_network" {
  description = "Network used for the vSphere virtual machines"
}

variable "vm_template" {
  description = "Template used to create the vSphere virtual machines"
}

variable "vm_folder" {
  description = "vSphere Virtual machines folder"
}

variable "vm_linked_clone" {
  description = "Use linked clone to create the vSphere virtual machines from the template (true/false). If you would like to use the linked clone feature, your template need to have one and only one snapshot"
}

variable "vm_ip" {
  description = "IP used for VM"
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


variable "vm_cpu" {
  description = "Number of vCPU for the  virtual machine"
}

variable "vm_ram" {
  description = "Amount of RAM for the virtual machine (example: 1024)"
}

variable "vm_hostname" {
  description = "Hostname of the VM"
}

variable "vm_name" {
  description = "Name of the VM"
}
