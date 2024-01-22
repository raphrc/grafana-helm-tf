terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.0.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.0.2"
    }
  }
}

provider "kind" {
}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/playground.config")
}

resource "kind_cluster" "default" {
  name          = "kind-playground-cluster"
  kubeconfig_path = pathexpand("~/.kube/playground.config")
  node_image    = "kindest/node:v1.24.0"
  wait_for_ready = true

  kind_config {
    kind       = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
    }

    node {
      role = "worker"
    }
  }
}

resource "kubernetes_namespace" "grafana_namespace" {
  metadata {
    name = "grafana-ns"
  }
}

resource "null_resource" "namespace_dependency" {
  depends_on = [kubernetes_namespace.grafana_namespace]
}

provider "helm" {
 kubernetes {
   config_path = pathexpand("~/.kube/playground.config")
}
}
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.grafana_namespace.metadata[0].name

  set {
    name  = "adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  depends_on = [null_resource.namespace_dependency, kind_cluster.default]
}

resource "null_resource" "generate_kubeconfig" {
  triggers = {
    cluster_name = kind_cluster.default.name
  }

  provisioner "local-exec" {
    command = "kind get kubeconfig --name=${kind_cluster.default.name} > ~/.kube/playground.config"
  }
}

