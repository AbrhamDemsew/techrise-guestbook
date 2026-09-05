# Terraform Infrastructure for TechRise Guestbook

This directory contains Terraform configuration to deploy the TechRise Guestbook application using Docker containers.

## Prerequisites

- Docker installed and running
- Terraform installed (version 1.0+)
- Docker provider for Terraform

## Setup

1. Initialize Terraform:
```bash
terraform init
```

2. (Optional) Customize configuration:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars to set your preferred port
```

3. Plan the deployment:
```bash
terraform plan
```

4. Apply the configuration:
```bash
terraform apply
```

## Infrastructure Components

- **Docker Network**: `guestbook-net` - Connects all containers
- **Redis Container**: Stores guestbook entries with persistent volume
- **Web Container**: Flask application serving the guestbook
- **Nginx Proxy**: Reverse proxy to the web application

## Outputs

After successful deployment, Terraform will output the guestbook URL:
```
guestbook_url = "http://localhost:8080"
```

## Cleanup

To destroy the infrastructure:
```bash
terraform destroy
```

## Variables

- `app_port`: Host port for the nginx proxy (default: 8080)
- `redis_volume_name`: Name for the Redis data volume (default: guestbook-redis-data)
