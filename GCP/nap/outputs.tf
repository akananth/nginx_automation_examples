output "external_name" {
    value = try(data.kubernetes_service_v1.nginx-service.status.0.load_balancer.0.ingress.0.ip, null)
}
output "external_port" {
    value = try(data.kubernetes_service_v1.nginx-service.spec.0.port.0.port, null)
}
output "origin_source" {
    value = "nap"
}

output "nap_deployment_name" {
    value = try (helm_release.nginx-plus-ingress.name)
    sensitive = true
}

