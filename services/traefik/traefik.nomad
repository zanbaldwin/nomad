job "traefik" {
  region = "global"
  type   = "system"

  group "traefik" {
    network {
      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
      port "api" {
        static = 8080
      }
    }

    service {
      name = "traefik"
      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "traefik-dashboard"
      port = "api"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.dashboard.rule=Host(`traefik.example.com`)",
        "traefik.http.routers.dashboard.entrypoints=websecure",
        "traefik.http.routers.dashboard.tls=true",
        "traefik.http.routers.dashboard.tls.certresolver=letsencrypt",
        "traefik.http.routers.dashboard.service=api@internal"
      ]
      check {
        name     = "dashboard"
        type     = "http"
        port     = "api"
        path     = "/dashboard/"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "traefik" {
      driver = "docker"
      constraint {
        attribute = "${node.class}"
        value     = "stateless"
      }
      config {
        image        = "traefik:v3.0"
        network_mode = "host"
        volumes = [
          "local/config.yaml:/etc/traefik/traefik.yml:ro",
        ]
      }
      template {
        data = file("config.yaml")
        destination = "local/config.yaml"
      }
      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
