#!/usr/bin/env bash

# Used in Dockerfile to build blog and run nginx
#
# First (and only) arg becomes the base url for the zola page.

set -euo pipefail
export BASE_URL=${1}
export OUTPUT_DIR="/usr/share/nginx/html"
zola build --force --output-dir "$OUTPUT_DIR" --base-url "$BASE_URL"

nginx -g 'daemon off;'
