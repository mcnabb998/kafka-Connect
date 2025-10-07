#!/usr/bin/env bash
set -euo pipefail

KEYTAB_DIR_DEFAULT="/opt/kafka-connect/secrets"
JAAS_FILE_DEFAULT="/opt/kafka-connect/config/jaas.conf"
GENERATOR_JAR_DEFAULT="/opt/kafka-connect/lib/keytab-generator.jar"

log() {
  local level="$1"; shift
  printf '[%s] %s\n' "$level" "$*"
}

load_env_file() {
  local env_name="${1:-${CONNECT_ENVIRONMENT:-default}}"
  local env_file="/deployments/env_files/${env_name}_env.conf"

  if [[ -f "$env_file" ]]; then
    log INFO "Loading environment configuration from ${env_file}"
    # shellcheck disable=SC1090
    source "$env_file"
  else
    log WARN "Environment file ${env_file} not found; continuing with existing environment variables"
  fi
}

ensure_directory() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
}

generate_keytab() {
  local principal="${KERBEROS_PRINCIPAL:-}"
  local password="${KERBEROS_PASSWORD:-}"
  local keytab_path="${KEYTAB_PATH:-${KEYTAB_DIR_DEFAULT}/app.keytab}"
  local generator_jar="${KEYTAB_GENERATOR_JAR:-${GENERATOR_JAR_DEFAULT}}"

  if [[ -z "$principal" ]]; then
    log INFO "KERBEROS_PRINCIPAL not set; skipping keytab generation"
    return 0
  fi

  if [[ ! -f "$generator_jar" ]]; then
    log ERROR "Keytab generator jar ${generator_jar} not found"
    return 1
  fi

  ensure_directory "$(dirname "$keytab_path")"

  local args=("--principal" "$principal" "--keytab" "$keytab_path")
  [[ -n "${KERBEROS_REALM:-}" ]] && args+=("--realm" "$KERBEROS_REALM")
  [[ -n "${KERBEROS_KDC:-}" ]] && args+=("--kdc" "$KERBEROS_KDC")
  [[ -n "${KERBEROS_ENCRYPTION:-}" ]] && args+=("--encryption" "$KERBEROS_ENCRYPTION")

  log INFO "Generating keytab for principal ${principal}"
  if [[ -n "$password" ]]; then
    JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-}" java -jar "$generator_jar" "${args[@]}" --password "$password"
  else
    JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-}" java -jar "$generator_jar" "${args[@]}"
  fi
}

configure_jaas() {
  local jaas_file="${KAFKA_JAAS_FILE:-${JAAS_FILE_DEFAULT}}"
  local keytab_path="${KEYTAB_PATH:-${KEYTAB_DIR_DEFAULT}/app.keytab}"
  local principal="${KERBEROS_PRINCIPAL:-}"

  if [[ -z "$principal" ]]; then
    log INFO "KERBEROS_PRINCIPAL not set; skipping JAAS file creation"
    return 0
  fi

  ensure_directory "$(dirname "$jaas_file")"

  cat >"$jaas_file" <<JAAS
KafkaClient {
  com.sun.security.auth.module.Krb5LoginModule required
  useKeyTab=true
  useTicketCache=false
  storeKey=true
  serviceName="kafka"
  keyTab="$keytab_path"
  principal="$principal";
};
JAAS

  export KAFKA_OPTS="${KAFKA_OPTS:-} -Djava.security.auth.login.config=$jaas_file"
  log INFO "Generated JAAS configuration at ${jaas_file}"
}

wait_for_connect_rest() {
  local rest_url="${1:-${CONNECT_REST_URL:-}}"
  local timeout="${CONNECT_REST_TIMEOUT_SECONDS:-300}"
  local interval="${CONNECT_REST_POLL_INTERVAL_SECONDS:-5}"

  if [[ -z "$rest_url" ]]; then
    log INFO "CONNECT_REST_URL not set; skipping REST readiness wait"
    return 0
  fi

  log INFO "Waiting for Kafka Connect REST API at ${rest_url} (timeout ${timeout}s)"
  local elapsed=0
  while (( elapsed < timeout )); do
    if curl --silent --show-error --fail "${rest_url}/connector-plugins" >/dev/null; then
      log INFO "Kafka Connect REST API is reachable"
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done

  log ERROR "Kafka Connect REST API at ${rest_url} was not reachable within ${timeout} seconds"
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  load_env_file "$@"
fi
