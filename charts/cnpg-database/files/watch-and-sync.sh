#!/usr/bin/env bash
set -euo pipefail

wait_for_secret() {
  local secret=$1
  echo "Waiting for secret $secret..." >&2
  until kubectl -n "$NAMESPACE" get secret "$secret" >/dev/null 2>&1; do
    sleep 5
  done
  echo "Secret $secret is available." >&2
}

get_secret_data() {
  local secret_name="$1"
  local key="$2"
  local jsonpath_key="${key//./\\.}"
  kubectl -n "$NAMESPACE" get secret "$secret_name" -o jsonpath="{.data['$jsonpath_key']}" | base64 -d || true
}

concatenate_root_ca() {
  local concatenated_cas=""
  while IFS= read -r item; do
    local ca_secret
    local ca_key
    ca_secret=$(echo "$item" | jq -r '.secretName')
    ca_key=$(echo "$item" | jq -r '.key')
    wait_for_secret "$ca_secret" >&2  # Logging to stderr
    local ca_cert
    ca_cert=$(get_secret_data "$ca_secret" "$ca_key")
    # Append to result without extra whitespace
    ca_cert=$(printf "%s" "$ca_cert")
    concatenated_cas="${concatenated_cas}${ca_cert}"$'\n'
  done <<< "$(echo "$ROOT_CA_SECRETS_JSON" | jq -c '.[]')"
  # Return result, trimming extra trailing newlines
  printf "%s" "$concatenated_cas"
}


push_secret() {
  local source_ca=$1
  local concatenated_root_ca=$2
  local target_secret=$3
  local tls_crt=$4
  local tls_key=$5

  local rendered_ca
  rendered_ca=$(printf "%s\n%s\n" "$source_ca" "$concatenated_root_ca")

  # Delete existing Secret to avoid immutable type error
  kubectl -n "$NAMESPACE" delete secret "$target_secret" --ignore-not-found

  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: $target_secret
  namespace: $NAMESPACE
  labels:
    cnpg.io/reload: "true"
  annotations:
    argocd.argoproj.io/sync-options: Skip
type: kubernetes.io/tls
data:
  tls.crt: $(echo -n "$tls_crt" | base64 -w0)
  tls.key: $(echo -n "$tls_key" | base64 -w0)
  ca.crt: $(echo -n "$rendered_ca" | base64 -w0)
EOF

  echo "Patched or created $target_secret" >&2
}

sync_fullchain() {
  local source_secret=$1
  local target_secret=$2
  local concatenated_root_ca=$3

  local source_ca tls_crt tls_key
  source_ca=$(get_secret_data "$source_secret" "ca.crt")
  tls_crt=$(get_secret_data "$source_secret" "tls.crt")
  tls_key=$(get_secret_data "$source_secret" "tls.key")

  if [[ -n "$source_ca" && -n "$tls_crt" && -n "$tls_key" ]]; then
    push_secret "$source_ca" "$concatenated_root_ca" "$target_secret" "$tls_crt" "$tls_key"
  else
    echo "Warning: Missing data in source secret $source_secret" >&2
  fi
}

# --- STARTUP ---
wait_for_secret "$SERVER_SECRET" >&2
wait_for_secret "$CLIENT_SECRET" >&2

concatenated_root_ca=$(concatenate_root_ca)

# Initial sync
sync_fullchain "$SERVER_SECRET" "$TARGET_SERVER_SECRET" "$concatenated_root_ca"
sync_fullchain "$CLIENT_SECRET" "$TARGET_CLIENT_SECRET" "$concatenated_root_ca"

echo "Starting watch loop..." >&2

while true; do
  echo "Starting a new watch loop..." >&2

  kubectl -n "$NAMESPACE" get secret -w | while read -r line; do
    secret_name=$(echo "$line" | awk '{print $1}')
    if [[ "$secret_name" == "$SERVER_SECRET" || "$secret_name" == "$CLIENT_SECRET" ]]; then
      echo "Change detected in $secret_name, syncing..." >&2
      concatenated_root_ca=$(concatenate_root_ca)
      sync_fullchain "$SERVER_SECRET" "$TARGET_SERVER_SECRET" "$concatenated_root_ca"
      sync_fullchain "$CLIENT_SECRET" "$TARGET_CLIENT_SECRET" "$concatenated_root_ca"
    fi
  done

  echo "Watch loop terminated. Restarting in 5s..." >&2
  sleep 5
done
