resource "kubernetes_manifest" "deployment_file" {
  manifest = yamldecode(file("k8s/load-balancer-example.yaml"))
}

resource "kubernetes_manifest" "service_file" {
  manifest = yamldecode(file("k8s/load-balancer-service.yaml"))
}
