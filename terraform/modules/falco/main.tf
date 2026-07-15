resource "helm_release" "falco" {
  name             = "falco"
  repository       = "https://falcosecurity.github.io/charts"
  chart            = "falco"
  version          = "4.8.0"
  namespace        = "falco"
  create_namespace = true

  set {
    name  = "driver.kind"
    value = "modern_ebpf"
  }

  set {
    name  = "falcosidekick.enabled"
    value = "true"
  }

  set {
    name  = "falcosidekick.config.slack.webhookurl"
    value = var.slack_webhook_url
  }

  set {
    name  = "falcosidekick.config.slack.minimumpriority"
    value = "warning"
  }

  values = [
    yamlencode({
      customRules = {
        "payment-rules.yaml" = <<-RULES
          - rule: Shell Spawned in Payment Container
            desc: A shell was spawned in a payment service container
            condition: >
              spawned_process and container and
              k8s.pod.label.app in (secret-reader) and
              proc.name in (sh, bash, zsh)
            output: >
              Shell spawned in payment container
              (user=%user.name container=%container.name
              image=%container.image.repository proc=%proc.name)
            priority: CRITICAL
            tags: [payment, shell]

          - rule: Sensitive File Read in Payment Container
            desc: A sensitive file was read in a payment service container
            condition: >
              open_read and container and
              k8s.pod.label.app in (secret-reader) and
              fd.name in (/etc/passwd, /etc/shadow, /etc/sudoers)
            output: >
              Sensitive file read in payment container
              (user=%user.name file=%fd.name
              container=%container.name)
            priority: WARNING
            tags: [payment, file-access]
        RULES
      }
    })
  ]

  timeout = 300
}
