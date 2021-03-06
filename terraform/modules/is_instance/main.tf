data "ibm_is_image" "ubuntu" {
  name = "ibm-ubuntu-20-04-minimal-amd64-2"
}

resource "ibm_is_volume" "second_disk" {
  count   = var.num_instances
  name    = format("%s%02d-second", var.name, count.index)
  profile = "10iops-tier"
  zone    = var.zone
}

resource "ibm_is_instance" "is_instance" {
  count   = var.num_instances
  name    = format("%s%02d", var.name, count.index)
  image   = data.ibm_is_image.ubuntu.id
  profile = "cx2-2x4"

  resource_group = var.resource_group

  primary_network_interface {
    subnet            = var.subnet_id
    security_groups   = [var.security_group_id]
    allow_ip_spoofing = true
  }

  vpc  = var.vpc_id
  zone = var.zone
  keys = [var.ssh_key_id]

  timeouts {
    # From experience, this sometimes takes longer than 30m, which is the
    # default.
    create = "60m"
    update = "60m"
    delete = "60m"
  }

  volumes = [ibm_is_volume.second_disk[count.index].id]

}

resource "ibm_is_floating_ip" "fip" {
  count             = var.num_instances
  name              = format("%s%02d", var.name, count.index)
  target            = ibm_is_instance.is_instance[count.index].primary_network_interface[0].id
  resource_group    = var.resource_group
}
