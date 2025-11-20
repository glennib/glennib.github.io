FROM nginx:mainline

# Install nginx

COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy zola binary from official image
COPY --from=ghcr.io/getzola/zola:v0.21.0 /bin/zola /usr/local/bin/zola

WORKDIR /blog

COPY run.sh run.sh
RUN chmod +x run.sh

ENV PATH="/blog:$PATH"

COPY config.toml .
COPY templates templates
COPY static static
COPY content content

EXPOSE 80
ENTRYPOINT [ "run.sh" ]
