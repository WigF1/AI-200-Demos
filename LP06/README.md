# LP06 — Enhance AI solutions with Azure Managed Redis

Source deck: `AI-200T00A-ENU-PowerPoint_06.pptx`

| Module | Topic | Lab |
|---|---|---|
| [M01](./M01) | Implement data operations in Azure Managed Redis | [01-amr-data-operations.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-managed-redis/01-amr-data-operations.md) |
| [M02](./M02) | Stream and coordinate events in Azure Redis (pub/sub + Streams) | [02-amr-pub-sub.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-managed-redis/02-amr-pub-sub.md) |
| [M03](./M03) | Implement vector storage in Azure Managed Redis | [03-amr-vector-storage.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-managed-redis/03-amr-vector-storage.md) |

Each module has `demo/scripts` (bash + PowerShell provisioning via
`az redisenterprise`) and `demo/python` (SDK scripts using `redis-py`).
Each module is self-contained - `00-ensure-prereqs` (M02/M03) recreates
the cluster if M01 hasn't run.

## Current best practice: Microsoft Entra ID over access keys

Confirmed against Microsoft's own docs (learn.microsoft.com/en-us/azure/
redis/scripts/create-manage-cache, checked 2026): "Microsoft Entra
authentication is enabled by default for all new caches and is
recommended for security... provides better security and is easier to
use than shared access key authorization." These demos use access keys
throughout to match the deck's own teaching content and keep the Python
examples approachable - for anything beyond a training exercise, prefer
Entra ID with managed identities instead (`az redisenterprise database
access-policy-assignment create`).

## Testing notes

M01 (data types, invalidation, key iteration) and M02 (streams with
multiple consumer groups, pub/sub) were re-verified against a real
3-node Redis Cluster (`redis-server --cluster-enabled yes`, formed with
`redis-cli --cluster create`) after initial single-node testing missed
two cross-slot bugs in M01 - a single node has no slot sharding and
structurally can't catch that category of bug (see LP06/M01/README.md
for the details, including a third, more subtle issue the real-cluster
pass caught: `KEYS` silently only returns matches from one shard).
M02's stream and pub/sub operations all passed against the real cluster
without changes needed - they operate on a single key/channel each, so
there was never a cross-slot risk there. M03
(vector storage via RediSearch) could only be partially verified this
way - the RediSearch module available for local testing (via apt) is an
old version that predates vector field support entirely, so its schema
and query syntax were verified through current documentation instead,
cross-checked against multiple independent sources. One real bug was
still caught in the process: `redis.commands.search.indexDefinition` -
shown in some current-looking documentation - doesn't exist in the
`redis` package version `pip install redis` actually installs; the real
module is `index_definition` (confirmed by direct testing against the
installed package, not just reading docs).
