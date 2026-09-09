# LP02 — Deploy and manage apps on Azure Container Apps

Source deck: `AI-200T00A-ENU-PowerPoint_02.pptx`

| Module | Topic | Lab |
|---|---|---|
| [M01](./M01) | Deploy containers to Azure Container Apps | [01-aca-deploy-containers.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-container-apps/01-aca-deploy-containers.md) |
| [M02](./M02) | Manage containers in Azure Container Apps | [02-aca-manage-containers.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-container-apps/02-aca-manage-containers.md) |
| [M03](./M03) | Scale containers in Azure Container Apps | [03-aca-scale-containers.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-container-apps/03-aca-scale-containers.md) |

Deploys the shared demo app in [`/shared/inference-api`](../shared/inference-api).
Each module is self-contained - `00-ensure-prereqs` bootstraps whatever it
needs if an earlier module hasn't run. Running M01 → M02 → M03 in order is
still the natural, faster path (later modules' bootstrap checks become
no-ops), but it's not required.

## Noisy but harmless: "behavior of this command has been altered by..."

`az containerapp` commands print `The behavior of this command has been
altered by the following extension: containerapp` (sometimes twice - once
prefixed `WARNING:`, once not) whenever the `containerapp` CLI extension
overrides a core command, which is most of the time. This is Azure CLI's
own notice, not an error - the command still runs correctly. To quiet it
globally across all your `az` usage (not just this repo), run once:

```bash
az config set core.only_show_errors=true
```

That also hides other future CLI warnings, so it's a trade-off, not
something baked into these scripts.

## M03: scale rules from 01, 02, and 03 all coexist regardless of order

`az containerapp update --scale-rule-name ...` replaces the app's entire
scale rule set by default (confirmed against Microsoft's own tutorial) -
so plain updates from `01-http-scale-rule` and `02-keda-servicebus-
scaler` would keep wiping each other's rule out, in EITHER order,
whichever ran second. Both scripts now go through the shared
`add_or_update_scale_rule` / `Add-OrUpdateScaleRule` helper
(`shared/lib/aca-scale-rules.{sh,ps1}`), which exports the current
config, lets the CLI generate the new rule in isolation, then splices it
into whatever else was already there before reapplying.

Recommended order is whatever's convenient for the demo you're giving -
e.g. `01` → `04` (HTTP scale-out) → `02` → `05` (KEDA scale-out) → `03`
(traffic split, independent of scale rules) - but any order, run any
number of times, leaves both rules intact. `04`/`05` each check for
their own rule and tell you which script to run first if it's missing.

One caveat: if your app's scale rules got into a bad state from an
earlier version of these scripts (before this fix), the fix can only
preserve rules that exist *at the time it runs* - it can't resurrect one
that was already wiped out in a previous session. Re-run whichever of
`01`/`02` is currently missing once to recreate it, and both should
survive every run after that.
