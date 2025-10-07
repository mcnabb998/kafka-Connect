#!/usr/bin/env bash
set -euo pipefail

REST_URL="${CONNECT_REST_URL:-http://localhost:8083}"
if ! curl --silent --show-error --fail "${REST_URL}/connectors" >/dev/null; then
  echo "Kafka Connect liveness check failed against ${REST_URL}" >&2
  exit 1
fi
