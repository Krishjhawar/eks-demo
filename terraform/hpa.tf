# ─── Horizontal Pod Autoscaler ────────────────────────────────────────────
# This is the core of the scaling demo.
# When CPU exceeds 50%, HPA increases pod replicas automatically.
# When load drops, it scales back down to min_replicas.

resource "kubernetes_horizontal_pod_autoscaler_v2" "demo_app" {
  metadata {
    name      = "demo-app-hpa"
    namespace = "default"

    annotations = {
      "description" = "Scales demo-app pods based on CPU utilization"
    }
  }

  spec {
    # Target deployment to scale
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "demo-app"
    }

    # Pod replica range
    min_replicas = var.hpa_min_replicas   # 1  — floor
    max_replicas = var.hpa_max_replicas   # 10 — ceiling

    # ── Scale-up metric: CPU utilization ────────────────────────────────
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = var.hpa_cpu_threshold  # 50%
        }
      }
    }

    # ── Scale-up metric: Memory utilization ─────────────────────────────
    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 70  # scale if memory > 70%
        }
      }
    }

    # ── Scaling behaviour: how fast to scale UP ──────────────────────────
    behavior {
      scale_up {
        stabilization_window_seconds = 30  # wait 30s before scaling up

        policy {
          type          = "Pods"
          value         = 2        # add 2 pods at a time
          period_seconds = 30
        }

        policy {
          type          = "Percent"
          value         = 100      # or double the current count
          period_seconds = 30
        }

        select_policy = "Max"      # use whichever adds more pods
      }

      # ── Scaling behaviour: how fast to scale DOWN ────────────────────
      scale_down {
        stabilization_window_seconds = 300  # wait 5 min before scaling down
                                            # gives demo time to show the pods

        policy {
          type           = "Pods"
          value          = 1       # remove 1 pod at a time
          period_seconds = 60
        }

        select_policy = "Min"      # be conservative scaling down
      }
    }
  }

  # HPA depends on the deployment existing first
  depends_on = [
    module.eks
  ]
}

# ─── Kubernetes Namespace for Monitoring ─────────────────────────────────
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"

    labels = {
      name    = "monitoring"
      purpose = "observability"
    }
  }

  depends_on = [module.eks]
}

# ─── Kubernetes Secret for app config ────────────────────────────────────
resource "kubernetes_secret" "app_config" {
  metadata {
    name      = "demo-app-config"
    namespace = "default"
  }

  data = {
    MAX_SESSIONS = base64encode(tostring(var.max_sessions))
  }

  type = "Opaque"

  depends_on = [module.eks]
}