variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "devops-rg-tf"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "switzerlandnorth"
}

variable "vm_name" {
  description = "Name of the Virtual Machine"
  type        = string
  default     = "devops-vm-tf"
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2ls_v2"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "devops"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "data_disk_size_gb" {
  description = "Size of Docker data disk in GB"
  type        = number
  default     = 32
}