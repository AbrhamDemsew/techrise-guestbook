variable "app_port" {
  description = "Host port published by the nginx proxy"
  type        = number
  default     = 8080
}

variable "redis_volume_name" {
  description = "Redis data volume name"
  type        = string
  default     = "guestbook-redis-data"
}
