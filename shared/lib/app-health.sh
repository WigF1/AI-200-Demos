#!/usr/bin/env bash
# Shared helper: poll a /health endpoint and confirm the app is ACTUALLY
# healthy, not just that something answered HTTP 200. Azure App Service
# serves its own default placeholder page (also HTTP 200) while a
# container is starting, restarting, or has failed to start entirely -
# checking the status code alone can't tell that apart from a real
# response from the app's own /health endpoint. This checks the response
# body for the app's own {"status": "healthy", ...} payload (see
# shared/inference-api/app.py's /health route) in addition to the code.
#
# Usage: source this file, then:
#   wait_for_app_health "$URL" true    # wait until genuinely healthy
#   wait_for_app_health "$URL" false   # wait until genuinely NOT healthy
#   wait_for_app_health "$URL" true 20 15   # optional: max attempts, delay seconds

wait_for_app_health() {
  local url="$1" expect_healthy="$2" max_attempts="${3:-12}" delay_seconds="${4:-10}"
  local attempt status body_file body is_healthy

  body_file=$(mktemp)
  for attempt in $(seq 1 "$max_attempts"); do
    # --max-time bounds a single request so a hanging/slow backend can't
    # silently inflate one "attempt" well past the delay_seconds you asked
    # for between attempts - without it curl will wait as long as the
    # server (or Azure's front end) takes to respond, which during a real
    # container failure can be much longer than you'd expect from the log.
    # --connect-timeout separately bounds just the connection phase, so a
    # fully-down backend fails fast rather than waiting out the full
    # --max-time budget.
    #
    # No "|| echo 000" fallback here on purpose: curl's own -w "%{http_code}"
    # already reliably prints "000" when no response was received (refused
    # connection, timeout, DNS failure, etc.), even though curl's exit code
    # is non-zero in that case. Adding a fallback on top of that produced
    # "000000" - curl's own "000" plus the fallback's "000" concatenated -
    # instead of "000".
    status=$(curl -s --connect-timeout 5 --max-time 15 -o "$body_file" -w "%{http_code}" "$url" 2>/dev/null)
    if [ -z "$status" ]; then
      status="000"
    fi
    body=$(cat "$body_file" 2>/dev/null)

    is_healthy="false"
    if [ "$status" = "200" ] && echo "$body" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"healthy"'; then
      is_healthy="true"
    fi

    if [ "$is_healthy" = "$expect_healthy" ]; then
      echo "HTTP $status, app healthy=$is_healthy (as expected) after ${attempt} attempt(s)."
      rm -f "$body_file"
      return 0
    fi
    echo "  attempt ${attempt}: HTTP $status, app healthy=$is_healthy - retrying in ${delay_seconds}s"
    sleep "$delay_seconds"
  done

  echo "Did not reach expected state (healthy=$expect_healthy) after $((max_attempts * delay_seconds))s (last: HTTP $status, app healthy=$is_healthy)." >&2
  rm -f "$body_file"
  return 1
}
