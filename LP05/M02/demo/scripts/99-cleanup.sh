#!/usr/bin/env bash
# There isn't a safe module-scoped cleanup here: removing VECTOR from
# azure.extensions risks clobbering other extensions someone else
# allowlisted on the same server (parameter set replaces the whole
# list), and the extension itself costs nothing to leave allowlisted.
# The tables this module's Python script creates (source_documents,
# document_chunks) live inside the database that LP05/M01/99-cleanup.sh
# (or the LP-level 99-cleanup-all.sh) deletes along with the server -
# there's nothing left to clean up independently of that.
echo "Nothing to clean up at the module level for LP05/M02 - the vector"
echo "extension allowlist entry is harmless to leave in place, and the"
echo "tables it created are removed when the server itself is deleted."
echo "Run ../../M01/demo/scripts/99-cleanup.sh or ../../99-cleanup-all.sh"
echo "to remove the server."
