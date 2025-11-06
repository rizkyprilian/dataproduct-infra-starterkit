FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl bash \
 && rm -rf /var/lib/apt/lists/*

ARG KUBECTL_VERSION=v1.34.1

RUN curl -fsSL -o /usr/local/bin/kubectl \
    https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
 && chmod +x /usr/local/bin/kubectl

ENTRYPOINT ["/bin/bash", "/scripts/watch-and-sync.sh"]
