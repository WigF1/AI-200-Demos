#!/usr/bin/env bash
# M03 doesn't create its own Azure resources - it uses the same Redis
# cluster as M01/M03. Nothing to clean up here beyond the keys/streams
# the Python demos create, which cost nothing meaningful to leave behind.
# Run LP06/M01/demo/scripts/99-cleanup.sh or ../../99-cleanup-all.sh to
# remove the cluster itself.
echo "Nothing to clean up at the module level for LP06/M03 - it shares"
echo "M01's Redis cluster rather than creating its own resources."
echo "Run ../../M01/demo/scripts/99-cleanup.sh or ../../99-cleanup-all.sh"
echo "to remove the cluster."
