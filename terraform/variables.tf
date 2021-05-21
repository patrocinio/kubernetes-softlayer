variable "zone" {
  # FIXME: for some reason, "eu-gb-1" does not work as a zone name.
  type    = string
  default = "us-east-1"
}

# These variables are supplied from the .envrc file in TF_VAR_xxx environment
# variables.
variable "SSH_PUBLIC_KEY" {}
variable "RESOURCE_PREFIX" {}
variable "NUM_MASTERS" {}
variable "NUM_WORKERS" {}