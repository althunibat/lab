
#===============================================================
# Docker Provider
#===============================================================
 provider "docker" {
  host = "tcp://${var.vm_ip}:2375/"
}
#==========================================
# Docker Data
#==========================================
 data "docker_registry_image" "nginx" {
  name = "nginx:alpine"
}

 #===============================================================================
# Docker Resources
#===============================================================================
 resource "docker_image" "nginx" {
  name          = "${data.docker_registry_image.nginx.name}"
  pull_triggers = ["${data.docker_registry_image.nginx.sha256_digest}"]
  depends_on = ["vsphere_virtual_machine.testvm"]
}
 resource "docker_container" "nginx" {
  name= "nginx"
  image = "${docker_image.nginx.name}"
  ports {
    internal = "80"
    external = "80"
  }
}