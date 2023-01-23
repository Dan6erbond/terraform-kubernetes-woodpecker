terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2022.8.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.13.1"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.17.1"
    }
    minio = {
      source  = "aminueza/minio"
      version = "1.10.0"
    }
  }
}

locals {
  match_labels = merge({
    "app.kubernetes.io/instance" = "woodpecker"
  }, var.match_labels)

  server_match_labels = merge({
    "app.kubernetes.io/name" = "woodpecker-server"
  }, local.match_labels)
  server_labels = merge(local.server_match_labels, {
    "app.kubernetes.io/version" = "v0.15.6"
  }, var.server_labels)

  agent_match_labels = merge({
    "app.kubernetes.io/name" = "woodpecker-agent"
  }, local.match_labels)
  agent_labels = merge(local.agent_match_labels, {
    "app.kubernetes.io/version" = "v0.15.6"
  }, var.agent_labels)
}

resource "kubernetes_service_account" "woodpecker_server" {
  metadata {
    name      = "woodpecker-server"
    namespace = var.namespace
    labels    = local.server_labels
  }
}

resource "kubernetes_deployment" "woodpecker_server" {
  metadata {
    name      = "woodpecker-server"
    namespace = var.namespace
    labels    = local.server_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.server_match_labels
    }
    template {
      metadata {
        labels = local.server_labels
        annotations = {
          "ravianand.me/config-hash" = sha1(jsonencode(merge(
            kubernetes_config_map.woodpecker_server.data,
            kubernetes_secret.woodpecker.data
          )))
        }
      }
      spec {
        service_account_name = kubernetes_service_account.woodpecker_server.metadata.0.name
        container {
          image = var.image_registry == "" ? "${var.server_image_repository}:${var.server_image_tag}" : "${var.image_registry}/${var.server_image_repository}:${var.server_image_tag}"
          name  = "woodpecker"
          env_from {
            config_map_ref {
              name = kubernetes_config_map.woodpecker_server.metadata.0.name
            }
          }
          env {
            name  = "WOODPECKER_BACKEND"
            value = "docker"
          }
          env {
            name = "WOODPECKER_AGENT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.woodpecker.metadata.0.name
                key  = "woodpecker-agent-secret"
              }
            }
          }
          env {
            name = "WOODPECKER_GITEA_SECRET"
            value_from {
              secret_key_ref {
                name     = kubernetes_secret.woodpecker.metadata.0.name
                key      = "gitea-secret"
                optional = true
              }
            }
          }
          env {
            name = "WOODPECKER_DATABASE_DATASOURCE"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.woodpecker.metadata.0.name
                key  = "database-url"
              }
            }
          }
          port {
            name           = "http"
            container_port = 8000
            protocol       = "TCP"
          }
          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8000
            }
          }
          readiness_probe {
            http_get {
              path = "/healthz"
              port = 8000
            }
          }
          resources {}
        }
      }
    }
  }
}

resource "kubernetes_service" "woodpecker_server" {
  metadata {
    name      = "woodpecker-server"
    namespace = var.namespace
    labels    = local.server_labels
  }
  spec {
    selector = local.server_match_labels
    type     = "ClusterIP"
    port {
      port        = 80
      name        = "http"
      target_port = 8000
    }
    port {
      port        = 9000
      name        = "grpc"
      target_port = 9000
    }
  }
}

resource "kubernetes_service_account" "woodpecker_agent" {
  count = var.woodpecker_agent_replicas == 0 ? 0 : 1
  metadata {
    name      = "woodpecker-agent"
    namespace = var.namespace
    labels    = local.agent_labels
  }
}

resource "kubernetes_deployment" "woodpecker_agent" {
  count = var.woodpecker_agent_replicas == 0 ? 0 : 1
  metadata {
    name      = "woodpecker-agent"
    namespace = var.namespace
    labels    = local.agent_labels
  }
  spec {
    replicas = var.woodpecker_agent_replicas
    selector {
      match_labels = local.agent_match_labels
    }
    template {
      metadata {
        labels = local.agent_labels
        annotations = {
          "ravianand.me/config-hash" = sha1(jsonencode(merge(
            kubernetes_secret.woodpecker.data
          )))
        }
      }
      spec {
        service_account_name = kubernetes_service_account.woodpecker_agent.0.metadata.0.name
        container {
          image = var.image_registry == "" ? "${var.agent_image_repository}:${var.agent_image_tag}" : "${var.image_registry}/${var.agent_image_repository}:${var.agent_image_tag}"
          name  = "woodpecker-agent"
          security_context {}
          env {
            name  = "WOODPECKER_SERVER"
            value = "${kubernetes_service.woodpecker_server.metadata.0.name}.${var.namespace}:9000"
          }
          env {
            name = "WOODPECKER_AGENT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.woodpecker.metadata.0.name
                key  = "woodpecker-agent-secret"
              }
            }
          }
          port {
            container_port = 3000
            name           = "http"
            protocol       = "TCP"
          }
          resources {
            requests = {
              cpu    = "250m"
              memory = "250Mi"
            }
            limits = {
              cpu    = 2
              memory = "2Gi"
            }
          }
          volume_mount {
            mount_path = "/var/run"
            name       = "sock-dir"
          }
        }
        container {
          image = "docker:20.10.12-dind"
          name  = "dind"
          env {
            name  = "DOCKER_DRIVER"
            value = "overlay2"
          }
          resources {
            requests = {
              cpu    = "250m"
              memory = "250Mi"
            }
            limits = {
              cpu    = 1
              memory = "2Gi"
            }
          }
          security_context {
            privileged = true
          }
          volume_mount {
            mount_path = "/var/run"
            name       = "sock-dir"
          }
        }
        volume {
          name = "sock-dir"
          empty_dir {}
        }
      }
    }
  }
}

resource "random_id" "woodpecker_agent_secret_key" {
  byte_length = 32
}

resource "kubernetes_secret" "woodpecker" {
  metadata {
    name      = "woodpecker"
    namespace = var.namespace
  }
  data = {
    "database-url"            = var.woodpecker_database_datasource
    "woodpecker-agent-secret" = random_id.woodpecker_agent_secret_key.hex
    "gitea-secret"            = var.woodpecker_gitea_secret
  }
}

resource "kubernetes_config_map" "woodpecker_server" {
  metadata {
    name      = "woodpecker-server-env"
    namespace = var.namespace
  }

  data = {
    WOODPECKER_ADMIN           = var.woodpecker_admin
    WOODPECKER_HOST            = var.woodpecker_host
    WOODPECKER_OPEN            = var.woodpecker_open
    WOODPECKER_ORGS            = var.woodpecker_orgs
    WOODPECKER_GITEA           = var.woodpecker_gitea
    WOODPECKER_GITEA_URL       = var.woodpecker_gitea_url
    WOODPECKER_GITEA_CLIENT    = var.woodpecker_gitea_client
    WOODPECKER_DATABASE_DRIVER = var.woodpecker_database_driver
  }
}
