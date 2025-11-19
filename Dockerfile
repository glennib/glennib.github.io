# Stage 1: Build
FROM debian:bookworm-slim AS builder

# Copy zola binary from official image
COPY --from=ghcr.io/getzola/zola:v0.21.0 /bin/zola /usr/local/bin/zola

WORKDIR /project

# Copy config first
COPY config.toml .

COPY templates templates
COPY static static
COPY content content

# Build
ARG BASE_URL
RUN if [ -n "$BASE_URL" ]; then \
    zola build --base-url "$BASE_URL"; \
    else \
    zola build; \
    fi

# Stage 2: Serve
FROM nginx:alpine

COPY --from=builder /project/public /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
