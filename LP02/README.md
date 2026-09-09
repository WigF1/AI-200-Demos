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

## M03: 01 and 02's scale rules coexist - no need to re-run either

`az containerapp update --scale-rule-name ...` replaces the app's entire
scale rule set by default (confirmed against Microsoft's own tutorial) -
so a naive `02-keda-servicebus-scaler` would silently delete `01-http-
scale-rule`'s rule instead of adding alongside it. `02` works around this
by exporting the current config, letting the CLI generate the new rule
in isolation, then splicing that rule into whatever was already there
and reapplying the merged result. Run `01` then `02` (in either order,
any number of times) and both rules - and `04`/`05`'s demos of each -
stay available without re-running the other.
