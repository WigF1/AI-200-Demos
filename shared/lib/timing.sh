#!/usr/bin/env bash
# Shared helper: track and print elapsed time.
#
# Whole-script timing is automatic - every 00-vars.sh sources this and
# sets a trap that prints total wall-clock time whenever the script
# exits, whether it finished normally, hit `exit N`, or aborted under
# set -e. You don't need to call anything for that part.
#
# For timing a single slow step (an AKS cluster create, a Container Apps
# environment create, etc.) inside a script, wrap it with time_step:
#   time_step "AKS cluster create" az aks create --resource-group ... 
#
# If a script needs its own EXIT trap for something else (e.g. killing a
# background port-forward), chain print_elapsed into that trap explicitly
# instead of setting a second trap (bash only keeps the last one):
#   trap 'kill "$PF_PID" 2>/dev/null || true; print_elapsed' EXIT

print_elapsed() {
  local mins=$((SECONDS / 60)) secs=$((SECONDS % 60))
  echo
  echo "Elapsed: ${mins}m ${secs}s"
}

time_step() {
  local label="$1"; shift
  local start=$SECONDS
  "$@"
  local status=$?
  local elapsed=$((SECONDS - start))
  local mins=$((elapsed / 60)) secs=$((elapsed % 60))
  echo "  [${label}: ${mins}m ${secs}s]"
  return $status
}
