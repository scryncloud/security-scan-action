#!/usr/bin/env bash
# Scryn Security Scan - used by the GitHub Action (scryncloud/security-scan-action)
# Reads config from env; writes scan_id, status, total_alerts to GITHUB_OUTPUT when set.

set -e

SCRYN_API_URL="${SCRYN_API_URL:-https://api.scryn.cloud}"
SCRYN_API_TOKEN="${SCRYN_API_TOKEN:-}"
TARGET_URL="${TARGET_URL:-}"
SCAN_TYPE="${SCAN_TYPE:-baseline}"
WAIT_FOR_COMPLETION="${WAIT_FOR_COMPLETION:-false}"
TIMEOUT="${TIMEOUT:-3600}"
OPENAPI_SPEC_URL="${OPENAPI_SPEC_URL:-}"
FAIL_ON_HIGH_OR_CRITICAL="${FAIL_ON_HIGH_OR_CRITICAL:-true}"

if [ -z "$SCRYN_API_TOKEN" ]; then
  echo "::error::SCRYN_API_TOKEN is required"
  exit 1
fi
if [ -z "$TARGET_URL" ]; then
  echo "::error::target_url (TARGET_URL) is required"
  exit 1
fi

echo "Creating Scryn security scan..."
echo "  Target URL: $TARGET_URL"
echo "  Scan Type: $SCAN_TYPE"

# Build JSON body (jq escapes special characters in URLs)
if [ -n "$OPENAPI_SPEC_URL" ]; then
  BODY=$(jq -n --arg url "$TARGET_URL" --arg type "$SCAN_TYPE" --arg spec "$OPENAPI_SPEC_URL" '{target_url: $url, scan_type: $type, openapi_spec_url: $spec}')
else
  BODY=$(jq -n --arg url "$TARGET_URL" --arg type "$SCAN_TYPE" '{target_url: $url, scan_type: $type}')
fi

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "${SCRYN_API_URL}/api/v1/scans/ci" \
  -H "Authorization: Bearer ${SCRYN_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$BODY")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESP_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ne 201 ]; then
  echo "::error::Failed to create scan (HTTP $HTTP_CODE)"
  echo "$RESP_BODY" | jq -r '.detail // .' 2>/dev/null || echo "$RESP_BODY"
  exit 1
fi

SCAN_ID=$(echo "$RESP_BODY" | jq -r '.id')
echo "✓ Scan created successfully (ID: $SCAN_ID)"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "scan_id=$SCAN_ID" >> "$GITHUB_OUTPUT"
fi

if [ "$WAIT_FOR_COMPLETION" != "true" ]; then
  exit 0
fi

echo ""
echo "Waiting for scan to complete (timeout: ${TIMEOUT}s)..."

START_TIME=$(date +%s)
POLL_INTERVAL=5
FINAL_STATUS=""
TOTAL_ALERTS="0"
HIGH_COUNT="0"

while true; do
  ELAPSED=$(($(date +%s) - START_TIME))
  if [ "$ELAPSED" -gt "$TIMEOUT" ]; then
    echo "::error::Scan timeout after ${TIMEOUT}s"
    exit 1
  fi

  STATUS_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X GET "${SCRYN_API_URL}/api/v1/scans/${SCAN_ID}" \
    -H "Authorization: Bearer ${SCRYN_API_TOKEN}")
  STATUS_HTTP=$(echo "$STATUS_RESPONSE" | tail -n1)
  STATUS_BODY=$(echo "$STATUS_RESPONSE" | sed '$d')

  if [ "$STATUS_HTTP" -eq 200 ]; then
    FINAL_STATUS=$(echo "$STATUS_BODY" | jq -r '.status')
    TOTAL_ALERTS=$(echo "$STATUS_BODY" | jq -r '.total_alerts // 0')
    HIGH_COUNT=$(echo "$STATUS_BODY" | jq -r '.high_count // 0')

    echo "[Scan $SCAN_ID] Status: $FINAL_STATUS (elapsed: ${ELAPSED}s)"

    if [ "$FINAL_STATUS" = "completed" ] || [ "$FINAL_STATUS" = "failed" ] || [ "$FINAL_STATUS" = "cancelled" ]; then
      echo "✓ Scan finished: $FINAL_STATUS, Total alerts: $TOTAL_ALERTS, High: $HIGH_COUNT"
      if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "status=$FINAL_STATUS" >> "$GITHUB_OUTPUT"
        echo "total_alerts=$TOTAL_ALERTS" >> "$GITHUB_OUTPUT"
      fi
      if [ "$FAIL_ON_HIGH_OR_CRITICAL" = "true" ] && [ "${HIGH_COUNT:-0}" -gt 0 ]; then
        echo "::warning::High severity vulnerabilities detected. Failing step (fail_on_high_or_critical=true)."
        exit 1
      fi
      exit 0
    fi
  fi

  sleep "$POLL_INTERVAL"
done
