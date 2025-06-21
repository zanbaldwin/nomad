variable "system_domain" {
  description = "Root domain to host all system services under"
  type        = string
  default     = "local"
}

job "traefik" {
  datacenters = ["hetzner"]
  type        = "service"
  priority    = 80

  group "traefik" {
    count = 1
    network {
      mode = "host"
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
      name = "traefik-api"
      port = "api"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.traefik-api.rule=Host(`api.traefik.${var.system_domain}`)",
        "traefik.http.routers.traefik-api.service=api@internal",
        "traefik.http.routers.traefik-api.middlewares=auth"
      ]
      check {
        name     = "dashboard"
        type     = "http"
        path     = "/ping"
        port     = "api"
        interval = "10s"
        timeout  = "2s"
      }
    }


    task "traefik" {
      driver = "docker"
      config {
        image = "traefik:v3.0"
        network_mode = "host"
        volumes = [
          "local/traefik.yml:/etc/traefik/traefik.yml:ro"
        ]
      }
      template {
        data        = file("./services/traefik/traefik.yml")
        destination = "local/traefik.yml"
      }
      template {
        data = "CONSUL_HTTP_TOKEN={{ key \"nomad-consul-token\" }}"
        destination = "secrets/consul_token"
        env = true
      }
      env {
        CONSUL_HTTP_ADDR = "127.0.0.1:8500"
        SYSTEM_DOMAIN = var.system_domain
      }
      resources {
        cpu    = 200
        memory = 256
      }
      kill_timeout = "20s"
    }
  }
}
