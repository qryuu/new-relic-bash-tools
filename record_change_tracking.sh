#!/usr/bin/env bash
# ==============================================================================
# record_change_tracking.sh
# 
# Records a Change Tracking event to New Relic via NerdGraph GraphQL API.
# Designed for AWS Systems Manager (SSM) and automated infrastructure maintenance.
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Hostname Resolution (Infrastructure Agent Compatible)
# ------------------------------------------------------------------------------
resolve_nr_hostname() {
  local config_file="/etc/newrelic-infra.yml"
  local resolved_name=""

  # 1-1. Check display_name or override_hostname in newrelic-infra.yml
  if [ -f "${config_file}" ]; then
    local display_name
    display_name=$(grep -E '^[[:space:]]*display_name:' "${config_file}" 2>/dev/null \
      | head -n 1 | awk '{print $2}' | tr -d '"'\''') || true

    if [ -n "${display_name}" ]; then
      echo "${display_name}"
      return 0
    fi

    local override_hostname
    override_hostname=$(grep -E '^[[:space:]]*override_hostname:' "${config_file}" 2>/dev/null \
      | head -n 1 | awk '{print $2}' | tr -d '"'\''') || true

    if [ -n "${override_hostname}" ]; then
      echo "${override_hostname}"
      return 0
    fi
  fi

  # 1-2. Fallback to FQDN
  resolved_name=$(hostname -f 2>/dev/null || true)
  if [ -n "${resolved_name}" ] && [ "${resolved_name}" != "localhost" ]; then
    echo "${resolved_name}"
    return 0
  fi

  # 1-3. Fallback to standard hostname
  hostname
}

# ------------------------------------------------------------------------------
# 2. API Key Resolution
# ------------------------------------------------------------------------------
resolve_api_key() {
  # 2-1. If NEW_RELIC_API_KEY environment variable is set, use it
  if [ -n "${NEW_RELIC_API_KEY:-}" ]; then
    echo "${NEW_RELIC_API_KEY}"
    return 0
  fi

  # 2-2. Optional: Try fetching from AWS SSM Parameter Store if aws-cli is available
  local ssm_param="${SSM_PARAMETER_NAME:-/newrelic/user-key}"
  if command -v aws >/dev/null 2>&1; then
    local key_from_ssm
    key_from_ssm=$(aws ssm get-parameter --name "${ssm_param}" --with-decryption --query "Parameter.Value" --output text 2>/dev/null || true)
    if [ -n "${key_from_ssm}" ] && [ "${key_from_ssm}" != "None" ]; then
      echo "${key_from_ssm}"
      return 0
    fi
  fi

  echo ""
}

# ------------------------------------------------------------------------------
# 3. Parameters
# ------------------------------------------------------------------------------
NR_API_KEY=$(resolve_api_key)
NR_ENDPOINT="${NEW_RELIC_ENDPOINT:-https://api.newrelic.com/graphql}"

if [ -z "${NR_API_KEY}" ]; then
  echo "[ERROR] New Relic User API Key is not found." >&2
  echo "        Set the NEW_RELIC_API_KEY environment variable or configure SSM Parameter Store (/newrelic/user-key)." >&2
  exit 1
fi

# Target host auto-resolved from newrelic-infra.yml or system hostname
TARGET_HOST="$(resolve_nr_hostname)"

# Arguments (optional overrides)
#   $1: Entity search query (Default: name = '<TARGET_HOST>' AND domain = 'INFRA')
#   $2: Version (Default: kernel version via uname -r)
#   $3: Description (Default: OS/Package update via AWS Systems Manager)
#   $4: User (Default: current user or ssm-user)
TARGET_QUERY="${1:-name = '${TARGET_HOST}' AND domain = 'INFRA'}"
CHANGE_VERSION="${2:-$(uname -r)}"
CHANGE_DESC="${3:-OS/Package periodic update via AWS Systems Manager}"
CHANGE_USER="${4:-${USER:-ssm-user}}"

echo "[INFO] Recording Change Tracking Event to New Relic..."
echo "  Target Host  : ${TARGET_HOST}"
echo "  Entity Query : ${TARGET_QUERY}"
echo "  Version      : ${CHANGE_VERSION}"
echo "  Description  : ${CHANGE_DESC}"
echo "  User         : ${CHANGE_USER}"

# ------------------------------------------------------------------------------
# 4. Payload & API Request (NerdGraph GraphQL)
# ------------------------------------------------------------------------------
PAYLOAD=$(cat <<EOF
{
  "query": "mutation CreateChangeEvent(\$event: ChangeTrackingEventInput!) { changeTrackingCreateEvent(changeTrackingEvent: \$event) { changeTrackingEvent { guid entity { name } } } }",
  "variables": {
    "event": {
      "entitySearch": {
        "query": "${TARGET_QUERY}"
      },
      "categoryAndTypeData": {
        "kind": {
          "category": "Deployment",
          "type": "Basic"
        }
      },
      "version": "${CHANGE_VERSION}",
      "description": "${CHANGE_DESC}",
      "user": "${CHANGE_USER}"
    }
  }
}
EOF
)

RESPONSE=$(curl -sS -X POST "${NR_ENDPOINT}" \
  -H "Content-Type: application/json" \
  -H "Api-Key: ${NR_API_KEY}" \
  -d "${PAYLOAD}")

# ------------------------------------------------------------------------------
# 5. Result Verification
# ------------------------------------------------------------------------------
if echo "${RESPONSE}" | grep -q '"errors"'; then
  echo "[ERROR] Failed to record change tracking event:" >&2
  echo "${RESPONSE}" >&2
  exit 1
else
  echo "[SUCCESS] Change tracking event recorded successfully."
  echo "${RESPONSE}"
fi
