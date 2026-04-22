FROM alpine:3.20

ARG MIHOMO_VERSION=v1.19.24
ARG TARGETARCH

RUN apk add --no-cache ca-certificates curl gzip sed bash

RUN set -eux; \
    arch="${TARGETARCH:-amd64}"; \
    case "$arch" in \
      amd64) release_arch="amd64" ;; \
      arm64) release_arch="arm64" ;; \
      arm) release_arch="armv7" ;; \
      *) echo "Unsupported TARGETARCH: $arch"; exit 1 ;; \
    esac; \
    url="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-${release_arch}-${MIHOMO_VERSION}.gz"; \
    curl -fL "$url" -o /tmp/mihomo.gz; \
    gzip -d /tmp/mihomo.gz; \
    mv /tmp/mihomo /usr/local/bin/mihomo; \
    chmod +x /usr/local/bin/mihomo

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
