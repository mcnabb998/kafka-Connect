#!/usr/bin/env bash
set -euo pipefail

REST_URL="${CONNECT_REST_URL:-http://localhost:8083}"
EXPECTED_PLUGIN="${CONNECT_REQUIRED_PLUGIN:-io.confluent.connect.jdbc.JdbcSourceConnector}"

response=$(curl --silent --show-error --fail "${REST_URL}/connector-plugins" || true)
if [[ -z "$response" ]]; then
  echo "Kafka Connect readiness check failed: REST API unavailable at ${REST_URL}" >&2
  exit 1
fi

echo "$response" | jq -e --arg plugin "$EXPECTED_PLUGIN" '.[] | select(.class == $plugin)' >/dev/null || {
  echo "Kafka Connect readiness check failed: plugin $EXPECTED_PLUGIN not reported" >&2
  exit 1
}
