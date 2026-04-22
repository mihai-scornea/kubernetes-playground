#!/usr/bin/env bash

set -uo pipefail

SERVICE_URL="${SERVICE_URL:-http://192.168.50.10:30090}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-0.35}"
WINDOW_SIZE=100
REPORT_EVERY=10

declare -a RESULTS=()
TOTAL_QUERIES=0

print_report() {
  local window_count="${#RESULTS[@]}"
  local a_count=0
  local b_count=0
  local timeout_count=0
  local item

  for item in "${RESULTS[@]}"; do
    case "$item" in
      A) ((a_count+=1)) ;;
      B) ((b_count+=1)) ;;
      TIMEOUT) ((timeout_count+=1)) ;;
    esac
  done

  local a_pct="0.00"
  local b_pct="0.00"
  local timeout_pct="0.00"

  if (( window_count > 0 )); then
    a_pct=$(awk -v count="$a_count" -v total="$window_count" 'BEGIN { printf "%.2f", (count * 100.0) / total }')
    b_pct=$(awk -v count="$b_count" -v total="$window_count" 'BEGIN { printf "%.2f", (count * 100.0) / total }')
    timeout_pct=$(awk -v count="$timeout_count" -v total="$window_count" 'BEGIN { printf "%.2f", (count * 100.0) / total }')
  fi

  echo
  echo "-----------------------"
  echo "After ${TOTAL_QUERIES} queries:"
  echo "Window size: ${window_count}"
  echo "A: ${a_pct}%"
  echo "B: ${b_pct}%"
  echo "Timeouts: ${timeout_pct}%"
  echo
  echo "ReplicaSets:"
  kubectl get rs -l app=nginx-rolling-demo \
    -o custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas,CURRENT:.status.replicas,READY:.status.readyReplicas,AVAILABLE:.status.availableReplicas
}

while true; do
  response="$(curl -sS --max-time "$TIMEOUT_SECONDS" "$SERVICE_URL" 2>/dev/null || true)"

  if [[ -z "$response" ]]; then
    RESULTS+=("TIMEOUT")
  elif [[ "$response" == *"Version A"* ]]; then
    RESULTS+=("A")
  elif [[ "$response" == *"Version B"* ]]; then
    RESULTS+=("B")
  else
    RESULTS+=("TIMEOUT")
  fi

  ((TOTAL_QUERIES+=1))

  if (( ${#RESULTS[@]} > WINDOW_SIZE )); then
    RESULTS=("${RESULTS[@]:1}")
  fi

  if (( TOTAL_QUERIES % REPORT_EVERY == 0 )); then
    print_report
  fi

  sleep 0.1
done
