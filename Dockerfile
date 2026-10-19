# Railway deployment wrapper for official Rebecca Panel.
# Official source and existing Reseller role are fetched at build time.
FROM debian:bookworm-slim AS source
ARG REBECCA_REF=master
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "${REBECCA_REF}" \
    https://github.com/rebeccapanel/Rebecca.git /src

FROM node:20-bookworm-slim AS dashboard
WORKDIR /src/dashboard
COPY --from=source /src/dashboard/package*.json ./
RUN npm ci
COPY --from=source /src/dashboard/ ./
RUN VITE_BASE_API=/api/ npm run build \
 && cp ./build/index.html ./build/404.html

FROM golang:1.25-bookworm AS tutorials
ARG HUGO_VERSION=0.147.7
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates wget \
 && wget -q "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb" -O /tmp/hugo.deb \
 && dpkg -i /tmp/hugo.deb \
 && rm -rf /var/lib/apt/lists/* /tmp/hugo.deb
WORKDIR /src
COPY --from=source /src/tutorials ./tutorials
RUN hugo --source ./tutorials --destination /out --cleanDestinationDir --gc --minify

FROM golang:1.25-bookworm AS builder
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bash build-essential ca-certificates git pkg-config \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY --from=source /src/ ./
COPY --from=dashboard /src/dashboard/build ./dashboard/build
COPY --from=tutorials /out ./dashboard/build/tutorial-content
RUN bash scripts/build_binary.sh

FROM debian:bookworm-slim AS runtime
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates certbot tzdata \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/rebecca
COPY --from=builder /src/dist/rebecca-server /usr/local/bin/rebecca-server
COPY --from=builder /src/dist/rebecca-cli /usr/local/bin/rebecca-cli
COPY --from=builder /src/templates ./templates
COPY railway-start.sh /usr/local/bin/railway-start
RUN chmod +x /usr/local/bin/railway-start \
 && mkdir -p /var/lib/rebecca/config /var/lib/rebecca/certs
ENV UVICORN_HOST=0.0.0.0 \
    REBECCA_DATA_DIR=/var/lib/rebecca \
    REBECCA_CONFIG_DIR=/var/lib/rebecca/config \
    REBECCA_CERT_BASE=/var/lib/rebecca/certs \
    SQLALCHEMY_DATABASE_URL=sqlite:////var/lib/rebecca/db.sqlite3
EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/railway-start"]
