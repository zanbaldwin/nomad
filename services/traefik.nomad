variable "system_domain" {
  description = "Root domain to host all system services under"
  type        = string
  default     = "local"
}

job "traefik" {
  datacenters = ["hetzner"]
  type        = "system"
  priority    = 80

  group "traefik" {
    count = 1
    network {
      port "web" {
        static = 80
      }
      port "websecure" {
        static = 443
      }
      port "api" {
        static = 8080
      }
    }

    service {
      name = "traefik"
      port = "web"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.api.rule=Host(`traefik.${var.system_domain}`)",
        "traefik.http.routers.api.service=api@internal",
        "traefik.http.routers.api.middlewares=auth",
        "traefik.http.middlewares.auth.basicauth.users=admin:$$2y$$10$$K.0WZ0O7T0QY8kzCzKHIU.lCL2ZQyG8iJG6kJrJvNmzSBl1rYZgRm"
      ]
      check {
        name     = "alive"
        type     = "tcp"
        port     = "web"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "api"
      port = "api"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.api.rule=Host(`api.traefik.${var.system_domain}`)",
        "traefik.http.routers.api.service=api@internal"
      ]
      check {
        name     = "dashboard"
        type     = "http"
        path     = "/api/rawdata"
        port     = "api"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"
      config {
        image = "traefik:v3.0"
        ports = ["web", "websecure", "api"]
        volumes = [
          "local/traefik.yml:/etc/traefik/traefik.yml:ro"
        ]
      }
      template {
        data        = file("./services/traefik/traefik.yml")
        destination = "local/traefik.yml"
      }
      env {
        CONSUL_HTTP_ADDR = "${NOMAD_IP_web}:8500"
      }
      resources {
        cpu    = 200
        memory = 256
      }
      kill_timeout = "20s"
    }
  }
}
