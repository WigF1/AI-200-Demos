#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../../../shared/lib/timing.sh"
trap print_elapsed EXIT

SUFFIX="${SUFFIX:-ai200lp05}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp05-postgresql}"
PG_SERVER="pg-${SUFFIX}"
PG_ADMIN_USER="pgadmin"
DB_NAME="agentdb"
# Password persists across runs in a gitignored local file - Azure has no
# way to retrieve an existing server's password, only reset it, so
# generating a fresh random one on every run (the original scaffold's
# behavior) would print a password that doesn't match the real server
# the moment the server already exists.
PG_PASSWORD_FILE="$(dirname "${BASH_SOURCE[0]}")/../../../.pg-admin-password"
echo "RESOURCE_GROUP=$RESOURCE_GROUP  PG_SERVER=$PG_SERVER  DB_NAME=$DB_NAME"
