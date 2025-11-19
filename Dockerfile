# Stage 1: Build the static site
FROM ghcr.io/getzola/zola:latest AS builder

WORKDIR /project

# Copy config first (changes less often)
COPY config.toml .

# Copy only necessary source directories
COPY content content
COPY static static
COPY templates templates

# Allow overriding base_url at build time (useful for k8s staging/prod)
ARG BASE_URL
RUN if [ -n "$BASE_URL" ]; then \
      zola build --base-url "$BASE_URL"; \
    else \
      zola build; \
    fi

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy static assets from builder
COPY --from=builder /project/public /usr/share/nginx/html

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
