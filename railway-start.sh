#!/bin/sh
set -eu

# Railway assigns PORT dynamically at runtime.
export UVICORN_HOST="${UVICORN_HOST:-0.0.0.0}"
export UVICORN_PORT="${PORT:-8000}"
export REBECCA_DATA_DIR="${REBECCA_DATA_DIR:-/var/lib/rebecca}"
export REBECCA_CONFIG_DIR="${REBECCA_CONFIG_DIR:-/var/lib/rebecca/config}"
export REBECCA_CERT_BASE="${REBECCA_CERT_BASE:-/var/lib/rebecca/certs}"
export SQLALCHEMY_DATABASE_URL="${SQLALCHEMY_DATABASE_URL:-sqlite:////var/lib/rebecca/db.sqlite3}"

mkdir -p "$REBECCA_DATA_DIR" "$REBECCA_CONFIG_DIR" "$REBECCA_CERT_BASE"

echo "Rebecca is binding to ${UVICORN_HOST}:${UVICORN_PORT}"
echo "Database URL: ${SQLALCHEMY_DATABASE_URL}"

# Apply migrations before starting the service.
rebecca-cli migrate up

exec rebecca-server
