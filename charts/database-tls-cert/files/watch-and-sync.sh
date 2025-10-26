#!/usr/bin/env bash
set -euo pipefail

# Expects:
# - CLIENT_CERT_NAMES (comma-separated list of cert names)
# - ROOT_CA_SECRET
# - ROOT_CA_KEY
# - NAMESPACE

wait_for_secret() {
  local secret=$1
  echo "Waiting for secret $secret..."
  until kubectl -n "$NAMESPACE" get secret "$secret" >/dev/null 2>&1; do
    sleep 5
  done
  echo "Secret $secret is available."
}

get_secret_data() {
  local secret_name="$1"
  local key="$2"

  # Escape dots in key for JSONPath
  local jsonpath_key="${key//./\\.}"
  
  kubectl -n "$NAMESPACE" get secret "$secret_name" -o jsonpath="{.data['$jsonpath_key']}" | base64 -d
}

push_secret() {
  local tls_crt=$1
  local tls_key=$2
  local ca_crt=$3
  local target_secret=$4

  kubectl -n "$NAMESPACE" create secret generic "$target_secret" \
      --from-literal=tls.crt="$tls_crt" \
      --from-literal=tls.key="$tls_key" \
      --from-literal=ca.crt="$ca_crt" \
      --type=kubernetes.io/tls \
      --dry-run=client -o yaml |
      kubectl label --local -f - "cnpg.io/reload=true" --dry-run=client -o yaml |
      kubectl annotate --local -f - "argocd.argoproj.io/sync-options=Skip" --dry-run=client -o yaml |
      kubectl apply -f -

  echo "Patched or created $target_secret"
}

sync_fullchain() {
  local cert_name=$1
  local root_ca=$2
  local source_secret="$cert_name"
  local target_secret="${cert_name}-fullchain"

  tls_crt=$(get_secret_data "$source_secret" "tls.crt")
  tls_key=$(get_secret_data "$source_secret" "tls.key")
  source_ca=$(get_secret_data "$source_secret" "ca.crt")

  concatenated_ca=$(echo -e "$source_ca\n$root_ca")
  push_secret "$tls_crt" "$tls_key" "$concatenated_ca" "$target_secret"
}

# Wait for initial secrets
wait_for_secret "$ROOT_CA_SECRET"
IFS=',' read -ra CERT_NAMES <<< "$CLIENT_CERT_NAMES"
for cert_name in "${CERT_NAMES[@]}"; do
  wait_for_secret "$cert_name"
done

ROOT_CA=$(get_secret_data "$ROOT_CA_SECRET" "$ROOT_CA_KEY")

# Initial sync
for cert_name in "${CERT_NAMES[@]}"; do
  sync_fullchain "$cert_name" "$ROOT_CA"
done

# Watch loop for all secrets
echo "Starting watch-and-sync.sh loop..."

while true; do
  echo "Starting a new watch loop..."
  
  # Watch for changes
  kubectl -n "$NAMESPACE" get secret -w |
  while read -r line; do
    secret_name=$(echo "$line" | awk '{print $1}')
    if [[ "$secret_name" == "$ROOT_CA_SECRET" || " ${CERT_NAMES[@]} " =~ " $secret_name " ]]; then
      echo "Change detected in $secret_name, syncing..."
      ROOT_CA=$(get_secret_data "$ROOT_CA_SECRET" "$ROOT_CA_KEY")
      for cert_name in "${CERT_NAMES[@]}"; do
        sync_fullchain "$cert_name" "$ROOT_CA"
      done
    fi
  done
  
  echo "Watch loop terminated (kubectl watch or connection error). Restarting in 10 seconds..."
  sleep 10
done