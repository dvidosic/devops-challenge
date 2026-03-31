output "aks_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_host" {
  description = "AKS API server endpoint"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].host
}

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.rg.name
}

output "get_credentials_command" {
  description = "Command to configure kubectl"
  value       = "az aks get-credentials --resource-group ${var.resource_group_name} --name ${var.aks_name}"
}

output "kube_config" {
  description = "Kubernetes config file content"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}