resource "ibm_is_ssh_key" "ssh-key" {
  name           = "${var.RESOURCE_PREFIX}-key"
  public_key     = "ssh-rsa ${var.SSH_PUBLIC_KEY}"
  resource_group = ibm_resource_group.group.id
}

resource "ibm_resource_group" "group" {
  name = "${var.RESOURCE_PREFIX}-group"
}

resource "ibm_is_vpc" "vpc" {
  name           = "${var.RESOURCE_PREFIX}-vpc"
  resource_group = ibm_resource_group.group.id
  
}

resource "ibm_is_subnet" "subnet" {
  name                     = "${var.RESOURCE_PREFIX}-subnet"
  vpc                      = ibm_is_vpc.vpc.id
  resource_group           = ibm_resource_group.group.id
  total_ipv4_address_count = "256"
  public_gateway           = ibm_is_public_gateway.public-gateway.id
  zone                     = var.zone

  //User can configure timeouts
  timeouts {
    create = "90m"
    delete = "30m"
  }
}

resource "ibm_is_security_group" "security_group" {
  vpc = ibm_is_vpc.vpc.id
  name = "${var.RESOURCE_PREFIX}-sg"
}

resource "ibm_is_security_group_rule" "sg-rule-inbound-ssh" {
//  group     = ibm_is_vpc.vpc.security_group[0].group_id
  group     = ibm_is_security_group.security_group.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "sg-rule-inbound-kube-api" {
//  group     = ibm_is_vpc.vpc.security_group[0].group_id
  group     = ibm_is_security_group.security_group.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 6443
    port_max = 6443
  }
}

resource "ibm_is_security_group_rule" "sg-rule-inbound-etcd" {
//  group     = ibm_is_vpc.vpc.security_group[0].group_id
  group     = ibm_is_security_group.security_group.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 2379
    port_max = 2380
  }
}


resource "ibm_is_security_group_rule" "sg-rule-inbound-https" {
  group     = ibm_is_security_group.security_group.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 443
    port_max = 443
  }
}

resource "ibm_is_security_group_rule" "sg-rule-inbound-api" {
  group     = ibm_is_security_group.security_group.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 30000
    port_max = 32767
  }
}

resource "ibm_is_security_group_rule" "sg-rule-inbound-api2" {
  group     = ibm_is_security_group.security_group.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  udp {
    port_min = 30000
    port_max = 32767
  }
}


resource "ibm_is_security_group_rule" "sg-rule-inbound-icmp" {
  group     = ibm_is_security_group.security_group.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  icmp {
    type = 8
  }
}

resource "ibm_is_security_group_rule" "sg-rule-outbound" {
  group     = ibm_is_security_group.security_group.id
  direction = "outbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 1
    port_max = 65535
  }
}

resource "ibm_is_security_group_rule" "sg-rule-outbound-all" {
  group     = ibm_is_security_group.security_group.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

# Hosts must have TCP/UDP/ICMP Layer 3 connectivity for all ports across hosts.
# You cannot block access to certain ports that might block communication across hosts.
resource "ibm_is_security_group_rule" "sg-rule-inbound-from-the-group" {
  group     = ibm_is_security_group.security_group.id
//  group     = ibm_is_vpc.vpc.security_group[0].group_id
  direction = "inbound"
//  remote    = ibm_is_vpc.vpc.security_group[0].group_id
  remote    = ibm_is_security_group.security_group.id
}

resource "ibm_is_security_group_rule" "sg-rule-outbound-to-the-group" {
  group     = ibm_is_security_group.security_group.id
//  group     = ibm_is_vpc.vpc.security_group[0].group_id
  direction = "outbound"
//  remote    = ibm_is_vpc.vpc.security_group[0].group_id
  remote    = ibm_is_security_group.security_group.id
}

resource "ibm_is_public_gateway" "public-gateway" {
  name           = "${var.RESOURCE_PREFIX}-public-gateway"
  vpc            = ibm_is_vpc.vpc.id
  zone           = var.zone
  resource_group = ibm_resource_group.group.id

  //User can configure timeouts
  timeouts {
    create = "90m"
  }
}

module "is_lb" {
  source = "../is_lb"

  name              = "${var.RESOURCE_PREFIX}-lb"
  subnet_id         = ibm_is_subnet.subnet.id
  resource_group    = ibm_resource_group.group.id
  security_group_id = ibm_is_security_group.security_group.id
}
