# LP05 — Develop AI solutions with Azure Database for PostgreSQL

Source deck: `AI-200T00A-ENU-PowerPoint_05.pptx`

| Module | Topic | Lab |
|---|---|---|
| [M01](./M01) | Build and query with Azure Database for PostgreSQL | [01-build-agent-tool-backend.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-database-postgresql/01-build-agent-tool-backend.md) |
| [M02](./M02) | Implement vector search with Azure Database for PostgreSQL | [02-implement-vector-search.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-database-postgresql/02-implement-vector-search.md) |
| [M03](./M03) | Optimize vector search in Azure Database for PostgreSQL | [03-optimize-vector-search.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-database-postgresql/03-optimize-vector-search.md) |

Each module has `demo/scripts` (bash + PowerShell provisioning via
`az postgres flexible-server`) and `demo/python` (SDK scripts using
`psycopg` for schema/query/vector work). Each module is self-contained -
`00-ensure-prereqs` (M02/M03) bootstraps the server/database if M01 hasn't run.

## Admin password persistence

Azure has no way to retrieve an existing server's password, only reset it - so
the admin password is generated once and cached in `.pg-admin-password` at the
LP05 root (gitignored, never committed). Every module's script reads that file
if present rather than generating a new password each run, which would silently
stop matching the real server. If the file is ever missing but the server
exists, the script resets the password and re-caches it - printed connection
details always reflect the password actually on the server.
