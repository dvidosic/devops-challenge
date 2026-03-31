variable "resource_group_name" {
  description = "Name of the existing Resource Group"
  type        = string
  default     = "devops-rg-tf"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "switzerlandnorth"
}

variable "aks_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "devops-aks-tf"
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 1
}

variable "node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_B2ls_v2"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}