terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "docker" {}



resource "docker_network" "guestbook" {
  name = "guestbook-net"
}

resource "docker_volume" "redis_data" {
  name = var.redis_volume_name
}

resource "docker_image" "redis" {
  name = "abraham37/redis:7-alpine"
}

resource "docker_container" "redis" {
  name    = "guestbook-redis"
  image   = docker_image.redis.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.guestbook.name
    aliases = ["redis"]
  }

  volumes {
    volume_name    = docker_volume.redis_data.name
    container_path = "/data"
  }

  healthcheck {
    test     = ["CMD", "redis-cli", "ping"]
    interval = "5s"
    timeout  = "3s"
    retries  = 5
  }
}

resource "docker_image" "web" {
  name = "guestbook-web:latest"

  build {
    context    = ".."
    dockerfile = "dockerfile"
  }
}

resource "docker_container" "web" {
  name    = "guestbook-web"
  image   = docker_image.web.image_id
  restart = "unless-stopped"

  env = [
    "REDIS_HOST=redis",
    "REDIS_PORT=6379",
  ]

  networks_advanced {
    name = docker_network.guestbook.name
    aliases = ["web"]
  }

  depends_on = [docker_container.redis]
}

resource "docker_image" "proxy" {
  name = "abraham37/nginx:alpine"
}

resource "docker_container" "proxy" {
  name    = "guestbook-proxy"
  image   = docker_image.proxy.image_id
  restart = "unless-stopped"

  ports {
    internal = 80
    external = var.app_port
  }

  volumes {
    host_path      = abspath("${path.module}/../nginx.conf")
    container_path = "/etc/nginx/nginx.conf"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.guestbook.name
  }

  depends_on = [docker_container.web]
}

output "guestbook_url" {
  description = "URL for the guestbook"
  value       = "http://localhost:${var.app_port}"
}
