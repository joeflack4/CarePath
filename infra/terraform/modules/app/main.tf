# App Module - Kubernetes resources for CarePath services

# Namespace
resource "kubernetes_namespace" "carepath" {
  metadata {
    name = var.namespace
    labels = {
      name        = var.namespace
      environment = var.environment
    }
  }
}

# Secret for MongoDB connection
resource "kubernetes_secret" "mongodb" {
  metadata {
    name      = "mongodb-secret"
    namespace = kubernetes_namespace.carepath.metadata[0].name
  }

  data = {
    MONGODB_URI = var.mongodb_connection_string
  }

  type = "Opaque"
}

# ConfigMap for shared configuration
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "app-config"
    namespace = kubernetes_namespace.carepath.metadata[0].name
  }

  data = {
    MONGODB_DB_NAME     = var.mongodb_db_name
    # When expose_db_api=true, the service uses port 80; otherwise port 8001
    DB_API_BASE_URL     = var.expose_db_api ? "http://db-api-service.${var.namespace}.svc.cluster.local:80" : "http://db-api-service.${var.namespace}.svc.cluster.local:8001"
    DEFAULT_LLM_MODE    = var.llm_mode
    VECTOR_MODE         = var.vector_mode
    LOG_LEVEL           = var.log_level
  }
}

#================================
# DB API Deployment and Service
#================================

resource "kubernetes_deployment" "db_api" {
  metadata {
    name      = "db-api"
    namespace = kubernetes_namespace.carepath.metadata[0].name
    labels = {
      app     = "db-api"
      service = "db-api"
    }
  }

  spec {
    replicas = var.db_api_replicas

    selector {
      match_labels = {
        app = "db-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "db-api"
        }
      }

      spec {
        container {
          name  = "db-api"
          image = var.db_api_image

          port {
            container_port = 8001
            name           = "http"
          }

          env {
            name = "MONGODB_URI"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongodb.metadata[0].name
                key  = "MONGODB_URI"
              }
            }
          }

          env {
            name = "MONGODB_DB_NAME"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "MONGODB_DB_NAME"
              }
            }
          }

          env {
            name  = "API_PORT_DB_API"
            value = "8001"
          }

          env {
            name = "LOG_LEVEL"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "LOG_LEVEL"
              }
            }
          }

          resources {
            requests = {
              cpu    = var.db_api_cpu_request
              memory = var.db_api_memory_request
            }
            limits = {
              cpu    = var.db_api_cpu_limit
              memory = var.db_api_memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8001
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8001
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "db_api" {
  metadata {
    name      = "db-api-service"
    namespace = kubernetes_namespace.carepath.metadata[0].name
    labels = {
      app = "db-api"
    }
  }

  spec {
    type = var.expose_db_api ? "LoadBalancer" : "ClusterIP"

    selector = {
      app = "db-api"
    }

    port {
      name        = "http"
      port        = var.expose_db_api ? 80 : 8001
      target_port = 8001
      protocol    = "TCP"
    }
  }
}

#================================
# Model Cache PersistentVolumeClaim (for LLM)
#================================

resource "kubernetes_persistent_volume_claim" "model_cache" {
  count = var.enable_model_cache_pvc ? 1 : 0

  # Don't wait for binding - PVC uses WaitForFirstConsumer and binds when pod starts
  wait_until_bound = false

  metadata {
    name      = "chat-api-model-cache"
    namespace = kubernetes_namespace.carepath.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "gp2"

    resources {
      requests = {
        storage = var.model_cache_storage_size
      }
    }
  }
}

#================================
# Chat API Deployment and Service
#================================

resource "kubernetes_deployment" "chat_api" {
  metadata {
    name      = "chat-api"
    namespace = kubernetes_namespace.carepath.metadata[0].name
    labels = {
      app     = "chat-api"
      service = "chat-api"
    }
  }

  spec {
    replicas = var.chat_api_replicas

    selector {
      match_labels = {
        app = "chat-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "chat-api"
        }
      }

      spec {
        container {
          name  = "chat-api"
          image = var.chat_api_image

          port {
            container_port = 8002
            name           = "http"
          }

          env {
            name = "DB_API_BASE_URL"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "DB_API_BASE_URL"
              }
            }
          }

          env {
            name = "DEFAULT_LLM_MODE"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "DEFAULT_LLM_MODE"
              }
            }
          }

          env {
            name = "VECTOR_MODE"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "VECTOR_MODE"
              }
            }
          }

          env {
            name  = "CHAT_API_PORT"
            value = "8002"
          }

          env {
            name = "LOG_LEVEL"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "LOG_LEVEL"
              }
            }
          }

          resources {
            requests = {
              cpu    = var.chat_api_cpu_request
              memory = var.chat_api_memory_request
            }
            limits = {
              cpu    = var.chat_api_cpu_limit
              memory = var.chat_api_memory_limit
            }
          }

          # LLM model is now loaded eagerly at startup via FastAPI lifespan handler.
          # The /ready endpoint returns 503 until model is loaded, then 200.
          # This means pod won't receive traffic until model is fully ready.
          #
          # Probes tuned for slow CPU inference (GGUF on r5.large):
          # - Inference runs in background thread, so health checks stay responsive
          # - Very conservative timeouts to handle worst-case scenarios
          liveness_probe {
            http_get {
              path = "/health"
              port = 8002
            }
            initial_delay_seconds = 180  # Wait 3 min for model to load before checking liveness
            period_seconds        = 120  # Check every 2 minutes (reduced log spam)
            timeout_seconds       = 180  # 3 min timeout per check (very conservative)
            failure_threshold     = 20   # 20 failures = 40 min grace period (120s × 20)
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 8002
            }
            initial_delay_seconds = 5    # Start checking quickly
            period_seconds        = 120  # Check every 2 minutes (reduced log spam)
            timeout_seconds       = 30   # 30s timeout (endpoint is lightweight)
            failure_threshold     = 120  # Allow 120 failures (120 × 120s = 4 hours for model load)
          }

          # Mount model cache PVC if enabled
          dynamic "volume_mount" {
            for_each = var.enable_model_cache_pvc ? [1] : []
            content {
              name       = "model-cache"
              mount_path = "/app/models"
            }
          }
        }

        # Volume for model cache PVC
        dynamic "volume" {
          for_each = var.enable_model_cache_pvc ? [1] : []
          content {
            name = "model-cache"
            persistent_volume_claim {
              claim_name = kubernetes_persistent_volume_claim.model_cache[0].metadata[0].name
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "chat_api" {
  metadata {
    name      = "chat-api-service"
    namespace = kubernetes_namespace.carepath.metadata[0].name
    labels = {
      app = "chat-api"
    }
    # ELB annotations for long-running LLM inference requests
    annotations = {
      # Increase idle timeout to 600s (10 min) for slow CPU inference
      "service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout" = "600"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "chat-api"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 8002
      protocol    = "TCP"
    }
  }
}

#================================
# Horizontal Pod Autoscalers
#================================

resource "kubernetes_horizontal_pod_autoscaler_v2" "db_api" {
  metadata {
    name      = "db-api-hpa"
    namespace = kubernetes_namespace.carepath.metadata[0].name
  }

  spec {
    min_replicas = var.hpa_min_replicas
    max_replicas = var.hpa_max_replicas

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.db_api.metadata[0].name
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = var.hpa_target_cpu_utilization
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "chat_api" {
  metadata {
    name      = "chat-api-hpa"
    namespace = kubernetes_namespace.carepath.metadata[0].name
  }

  spec {
    min_replicas = var.hpa_min_replicas
    max_replicas = var.hpa_max_replicas

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.chat_api.metadata[0].name
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = var.hpa_target_cpu_utilization
        }
      }
    }
  }
}
