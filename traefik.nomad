job "traefik" {
  region      = "global"
  datacenters = ["hetzner"]
  type        = "system"

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
          "local/traefik.yml:/etc/traefik/traefik.yml",
        ]
      }

      template {
        data = <<EOF
# Traefik static configuration file
global:
  checkNewVersion: false
  sendAnonymousUsage: false

serversTransport:
  insecureSkipVerify: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true

  websecure:
    address: ":443"

providers:
  consul:
    endpoints:
      - "127.0.0.1:8500"
    rootKey: "traefik"

  consulCatalog:
    prefix: traefik
    exposedByDefault: false
    endpoints:
      - "127.0.0.1:8500"

certificatesResolvers:
  letsencrypt:
    acme:
      tlsChallenge: {}
      email: admin@example.com  # Change this to your email
      storage: "consul"
      caServer: https://acme-v02.api.letsencrypt.org/directory
      keyType: EC256

api:
  dashboard: true
  insecure: true

http:
  services:
    nomad-servers:
      loadBalancer:
        servers:
          - url: "http://10.0.0.16:4646"
    consul-servers:
      loadBalancer:
        servers:
          - url: "http://10.0.0.16:8500"

  routers:
    nomad-ui:
      rule: "Host(`nomad.example.com`)"
      entryPoints:
        - "websecure"
      service: "nomad-servers"
      tls:
        certResolver: "letsencrypt"
    
    consul-ui:
      rule: "Host(`consul.example.com`)"
      entryPoints:
        - "websecure" 
      service: "consul-servers"
      tls:
        certResolver: "letsencrypt"

log:
  level: INFO

accessLog: {}
EOF

        destination = "local/traefik.yml"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}