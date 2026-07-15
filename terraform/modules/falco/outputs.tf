output "falco_namespace" {
  description = "Namespace where Falco is installed"
  value       = helm_release.falco.namespace
}
