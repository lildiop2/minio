# syntax=docker/dockerfile:1
# Multi-stage build for MinIO from source

# Stage 1: Build MinIO and gather runtime dependencies
FROM golang:1.24-alpine AS build

ARG TARGETARCH=amd64
ARG RELEASE=DEVELOPMENT
ARG COMMIT_ID=""
ARG SHORT_COMMIT_ID=""
ARG MC_RELEASE=RELEASE.2025-08-13T08-35-41Z

ENV GOPATH=/go \
    CGO_ENABLED=0

WORKDIR /build

RUN apk add -U --no-cache ca-certificates curl bash git

# Download MinIO Client (mc) binary
RUN case "${TARGETARCH}" in \
        "amd64") MC_ARCH="amd64" ;; \
        "arm64") MC_ARCH="arm64" ;; \
        "ppc64le") MC_ARCH="ppc64le" ;; \
        "s390x") MC_ARCH="s390x" ;; \
        *) MC_ARCH="${TARGETARCH}" ;; \
    esac && \
    echo "Downloading MinIO Client (mc ${MC_RELEASE}) for ${MC_ARCH}..." && \
    curl -f -s -L "https://github.com/minio/mc/releases/download/${MC_RELEASE}/mc.linux-${MC_ARCH}.${MC_RELEASE}" -o /go/bin/mc && \
    chmod +x /go/bin/mc

# Download static curl
COPY dockerscripts/download-static-curl.sh /build/download-static-curl
RUN chmod +x /build/download-static-curl && \
    TARGETARCH="${TARGETARCH}" /build/download-static-curl

# Copy MinIO source
COPY . /build/src

# Compile MinIO with release metadata
RUN cd /build/src && \
    COMMIT_ID_VAL="${COMMIT_ID}" && \
    if [ -z "${COMMIT_ID_VAL}" ]; then \
        COMMIT_ID_VAL=$(git rev-parse HEAD 2>/dev/null || echo "custom"); \
    fi && \
    SHORT_COMMIT_ID_VAL="${SHORT_COMMIT_ID}" && \
    if [ -z "${SHORT_COMMIT_ID_VAL}" ]; then \
        SHORT_COMMIT_ID_VAL=$(echo "${COMMIT_ID_VAL}" | cut -c1-12); \
    fi && \
    VERSION_VAL="$(echo "${RELEASE}" | sed -E 's/^RELEASE\.([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2})-([0-9]{2})-([0-9]{2})Z/\1T\2:\3:\4Z/')" && \
    if [ "${VERSION_VAL}" = "${RELEASE}" ]; then \
        VERSION_VAL="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; \
    fi && \
    YEAR_VAL="$(echo "${VERSION_VAL}" | cut -d'-' -f1)" && \
    LDFLAGS="-s -w \
      -X github.com/minio/minio/cmd.Version=${VERSION_VAL} \
      -X github.com/minio/minio/cmd.CopyrightYear=${YEAR_VAL} \
      -X github.com/minio/minio/cmd.ReleaseTag=${RELEASE} \
      -X github.com/minio/minio/cmd.CommitID=${COMMIT_ID_VAL} \
      -X github.com/minio/minio/cmd.ShortCommitID=${SHORT_COMMIT_ID_VAL}" && \
    echo "Compiling MinIO (${RELEASE}) for linux/${TARGETARCH}..." && \
    GOOS=linux GOARCH=${TARGETARCH} go build -tags kqueue -trimpath --ldflags "${LDFLAGS}" -o /go/bin/minio .

# Stage 2: Final minimal runtime image (UBI Micro)
FROM registry.access.redhat.com/ubi9/ubi-micro:latest

ARG RELEASE=DEVELOPMENT

LABEL name="MinIO" \
      vendor="MinIO Community Fork <lildiop2>" \
      maintainer="lildiop2" \
      version="${RELEASE}" \
      release="${RELEASE}" \
      summary="MinIO High Performance Object Storage" \
      description="MinIO object storage community build from source for homelab and production."

ENV MINIO_ACCESS_KEY_FILE=access_key \
    MINIO_SECRET_KEY_FILE=secret_key \
    MINIO_ROOT_USER_FILE=access_key \
    MINIO_ROOT_PASSWORD_FILE=secret_key \
    MINIO_KMS_SECRET_KEY_FILE=kms_master_key \
    MINIO_CONFIG_ENV_FILE=config.env \
    MC_CONFIG_DIR=/tmp/.mc

RUN chmod -R 777 /usr/bin

COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /go/bin/minio /usr/bin/minio
COPY --from=build /go/bin/mc /usr/bin/mc
COPY --from=build /go/bin/curl /usr/bin/curl

COPY CREDITS /licenses/CREDITS
COPY LICENSE /licenses/LICENSE
COPY dockerscripts/docker-entrypoint.sh /usr/bin/docker-entrypoint.sh

EXPOSE 9000 9001
VOLUME ["/data"]

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["minio"]
