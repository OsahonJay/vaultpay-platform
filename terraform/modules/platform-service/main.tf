data "aws_caller_identity" "current" {}

resource "aws_iam_role" "service" {
  name = "${var.environment}-${var.service_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.namespace}:${var.service_name}-sa"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    environment = var.environment
    managed-by  = "terraform"
    service     = var.service_name
  }
}

resource "kubernetes_namespace" "service" {
  metadata {
    name = var.namespace
    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}


resource "aws_iam_role_policy" "service_secrets" {
  name = "${var.environment}-${var.service_name}-secrets-policy"
  role = aws_iam_role.service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:eu-west-2:${data.aws_caller_identity.current.account_id}:secret:${var.secret_name}-*"
    }]
  })
}

resource "kubernetes_service_account" "service" {
  metadata {
    name      = "${var.service_name}-sa"
    namespace = kubernetes_namespace.service.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.service.arn
    }
  }
}

resource "kubernetes_deployment" "service" {
  metadata {
    name      = var.service_name
    namespace = kubernetes_namespace.service.metadata[0].name
    labels = {
      app         = var.service_name
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = var.service_name
      }
    }

    template {
      metadata {
        labels = {
          app         = var.service_name
          environment = var.environment
        }
      }

      spec {
        service_account_name = kubernetes_service_account.service.metadata[0].name

        container {
          name              = var.service_name
          image             = var.container_image
          image_pull_policy = "Always"

          port {
            container_port = var.container_port
          }

          env {
            name  = "SECRET_NAME"
            value = var.secret_name
          }

          env {
            name  = "AWS_REGION"
            value = "eu-west-2"
          }

          resources {
            requests = {
              cpu    = var.resources.requests_cpu
              memory = var.resources.requests_memory
            }
            limits = {
              cpu    = var.resources.limits_cpu
              memory = var.resources.limits_memory
            }
          }

          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
            read_only_root_filesystem  = true
            capabilities {
              drop = ["NET_RAW"]
            }

          }
          readiness_probe {
            http_get {
              path = "/health"
              port = var.container_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
          liveness_probe {
            http_get {
              path = "/health"
              port = var.container_port
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "service" {
  metadata {
    name      = var.service_name
    namespace = kubernetes_namespace.service.metadata[0].name
  }

  spec {
    selector = {
      app = var.service_name
    }

    port {
      port        = 80
      target_port = var.container_port
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_network_policy" "service" {
  metadata {
    name      = "${var.service_name}-netpol"
    namespace = kubernetes_namespace.service.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = var.service_name
      }
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = var.namespace
          }
        }
      }
    }

    policy_types = ["Ingress", "Egress"]
  }
}
