variable "system_domain" {
  description = "Root domain to host all system services under"
  type        = string
  default     = "local"
}

job "nomad-ui" {
  datacenters = ["hetzner"]
  type        = "service"
  priority    = 70

  group "nomad-ui" {
    count = 1

    constraint {
      attribute = "${attr.consul.server}"
      value     = "true"
    }

    network {
      port "ui" {}
    }

    service {
      name = "nomad-ui"
      port = "ui"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nomad-ui.rule=Host(`nomad.${var.system_domain}`)",
        "traefik.http.routers.nomad-ui.middlewares=auth",
        "traefik.http.middlewares.auth.basicauth.users=admin:$$2y$$10$$K.0WZ0O7T0QY8kzCzKHIU.lCL2ZQyG8iJG6kJrJvNmzSBl1rYZgRm"
      ]
      check {
        name     = "nomad-ui-health"
        type     = "http"
        path     = "/v1/status/leader"
        port     = "ui"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "nomad-proxy" {
      driver = "docker"
      config {
        image = "nginx:alpine"
        ports = ["ui"]
        volumes = [
          "local/nginx.conf:/etc/nginx/nginx.conf:ro"
        ]
      }
      template {
        data = <<EOF
events {
    worker_connections 1024;
}

http {
    server {
        listen ${NOMAD_PORT_ui};
        
        location / {
            proxy_pass http://${NOMAD_HOST_IP_ui}:4646;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF
        destination = "local/nginx.conf"
      }
      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}