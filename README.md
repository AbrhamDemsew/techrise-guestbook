# TechRise Guestbook

A simple web guestbook where visitors can leave their name and a message.
Built with Flask, Redis, and nginx, all orchestrated with Docker Compose.

## Prerequisites

Docker and Docker Compose. Nothing else is required on the host machine.

## How to Run

```bash
# 1. Clone the repository
git clone https://github.com/AbrhamDemsew/techrise-guestbook.git
cd techrise-guestbook

# 2. Copy the example environment file
cp .env.example .env
# Edit .env if needed. The default values work as-is.

# 3. Start the application
docker compose up -d --build

# 4. Open the guestbook in your browser
# http://localhost:8080
```

Check the application health endpoint:

```bash
curl http://localhost:8080/health
```

Expected response:

```json
{"status":"ok"}
```

## Architecture

Three services run together:

<img width="517" height="451" alt="The Arc" src="https://github.com/user-attachments/assets/bf95be45-e74d-4e9c-ada2-da758e235a84" />


- **proxy** (`nginx:alpine`): The only public-facing service. It publishes port
  `8080` and reverse-proxies requests to the web service.
- **web** (built from `Dockerfile`): The Flask application. It has no public
  port and is reachable only through the proxy.
- **redis** (`redis:7-alpine`): Stores the guestbook messages. It has no public
  port and is reachable only by the web service. Its data persists in a named
  Docker volume.

Request flow:

```text
Browser -> proxy:8080 -> web:5000 -> redis:6379
```

The services communicate over the private network created by Docker Compose.
The service names `web` and `redis` are used as internal hostnames.

## Project Structure

```text
.
├── .dockerignore
├── .env.example
├── .gitignore
├── .github/
│   └── workflows/
│       └── ci.yml
├── app.py
├── docker-compose.yml
├── Dockerfile
├── guide.md
├── instruction.md
├── nginx.conf
├── README.md
└── requirements.txt
```

## Environment Variables

The application reads its configuration from environment variables:

| Variable | Description | Example |
|---|---|---|
| `REDIS_HOST` | Redis service hostname | `redis` |
| `REDIS_PORT` | Redis port inside Docker | `6379` |
| `APP_PORT` | Host port published by nginx | `8080` |

The `.env` file is ignored by Git and must never be committed. The
`.env.example` file documents the required variables and is safe to commit.

## Data Persistence

Redis stores messages in the named `redis_data` volume. Messages survive when
containers are stopped and removed with:

```bash
docker compose down
docker compose up -d
```

To remove the containers and the stored messages:

```bash
docker compose down -v
```

## CI Pipeline

GitHub Actions builds and tests the application on pushes to the `main` branch
and on pull requests.

The pipeline:

1. Checks out the repository.
2. Creates a test `.env` file.
3. Builds and starts the Docker Compose stack.
4. Waits for the `/health` endpoint to report a healthy application.
5. Submits a test guestbook entry and verifies that it appears on the homepage.
6. Displays service logs when a step fails.
7. Tears down the test environment.

The workflow is located at `.github/workflows/ci.yml`.

## What Broke and How I Fixed It

### Problem 1: Terraform Docker Image Pull Failures

**What happened:** I encountered repeated Docker image pull failures when running `terraform apply`. The error message was:

```
Error: Unable to read Docker image into resource: unable to pull image redis:7-alpine: 
error pulling image redis:7-alpine: Error response from daemon: failed to resolve reference 
"docker.io/library/redis:7-alpine": failed to do request: Head 
"https://registry-1.docker.io/v2/library/redis/manifests/7-alpine": 
dial tcp [2600:1f18:2148:bc01:3ebc:5fea:5e26:4a57]:443: connect: network is unreachable
```

**Why it happened:** My system had IPv6 connectivity issues to Docker Hub's registry. Terraform was trying to pull official Docker images but couldn't reach them due to IPv6 network unreachability errors.

**How I fixed it:** I bypassed the official Docker Hub registry by using my personal Docker Hub account:

1. First, I logged into Docker Hub (after fixing credential storage issues):
   ```bash
   docker login -u abraham37
   ```

2. I tagged the locally available images for my Docker Hub account:
   ```bash
   docker tag redis:7-alpine abraham37/redis:7-alpine
   docker tag nginx:alpine abraham37/nginx:alpine
   ```

3. I pushed the images to my personal Docker Hub:
   ```bash
   docker push abraham37/redis:7-alpine
   docker push abraham37/nginx:alpine
   ```

4. I updated the Terraform configuration to use my images:
   ```hcl
   resource "docker_image" "redis" {
     name = "abraham37/redis:7-alpine"
   }
   resource "docker_image" "proxy" {
     name = "abraham37/nginx:alpine"
   }
   ```

This approach successfully bypassed the IPv6 connectivity issues since my Docker Hub account was accessible.

### Problem 2: DNS Resolution Between Terraform Containers

**What happened:** After successfully deploying the containers with Terraform, I got a `502 Bad Gateway` error when accessing the application. The web container couldn't connect to Redis, and nginx couldn't reach the web service.

**Why it happened:** The containers were deployed on the same Docker network but couldn't resolve each other by hostname. When I tested DNS resolution from within the web container, I got:
```
socket.gaierror: [Errno -2] Name or service not known
```

**How I fixed it:** I added network aliases to the Terraform container configurations to enable proper DNS resolution:

```hcl
resource "docker_container" "redis" {
  name    = "guestbook-redis"
  image   = docker_image.redis.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.guestbook.name
    aliases = ["redis"]  # Added this for DNS resolution
  }
  # ... rest of configuration
}

resource "docker_container" "web" {
  name    = "guestbook-web"
  image   = docker_image.web.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.guestbook.name
    aliases = ["web"]  # Added this for DNS resolution
  }
  # ... rest of configuration
}
```

After adding the network aliases, the containers could resolve each other by hostname (`redis`, `web`), and the application worked correctly.

**What I changed:** I made sure the Flask service was named `web` and that the
nginx configuration used the same hostname:

```nginx
proxy_pass http://web:5000;
```

I rebuilt and restarted the stack:

```bash
docker compose up -d --build
```

### Problem 3: The web service could not connect to Redis

**What happened:** The health endpoint returned a degraded response, and the
web service logs showed a Redis connection error.

**Why it happened:** The application was configured to use the wrong Redis
hostname. Inside a Docker container, `localhost` refers to that same container,
not to the Redis container.

**What I changed:** I configured the Redis service name in `.env`:

```env
REDIS_HOST=redis
REDIS_PORT=6379
```

After restarting the stack, the health endpoint returned `{"status":"ok"}`.

## Useful Commands

View the status of all services:

```bash
docker compose ps
```

View service logs:

```bash
docker compose logs
docker compose logs -f web
```

Open a shell inside the web container:

```bash
docker compose exec web sh
```

Rebuild after changing application code:

```bash
docker compose up -d --build
```

## Security Notes

- Nginx is the only service that publishes a host port.
- The Flask web service has no public port.
- Redis has no public port.
- `.env` is excluded from Git and Docker builds.
- Nginx forwards external requests to the private web service.

## License

This project was created as part of the TechRise DevOps capstone project.
