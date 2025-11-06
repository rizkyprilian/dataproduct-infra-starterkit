# Use an official lightweight base image
FROM alpine:3

# Set the desired Helm version
ENV HELM_VERSION v3.15.1

# Install necessary packages
RUN apk add --no-cache curl ca-certificates bash

# Install Helm
RUN curl -L https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar zxv -C /tmp \
    && mv /tmp/linux-amd64/helm /usr/bin/helm \
    && chmod +x /usr/bin/helm \
    && rm -rf /tmp/linux-amd64
# Set the working directory
WORKDIR /apps
# Default to bash
CMD ["bash"]