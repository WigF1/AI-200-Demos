# LP08 / M02 — Manage application settings with Azure App Configuration

**Lab:** [02-exercise-retrieve-settings.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/app-sec-config/02-exercise-retrieve-settings.md)

## Learning objectives (from the deck)
- Connect to App Configuration with managed identity, retrieve settings via the Python provider
- Organize settings with labels; implement feature flags
- Reference Key Vault secrets from App Configuration
- Decide what belongs in App Configuration vs. Key Vault

## Contents

- `demo/scripts/01-create-app-configuration` (bash/ps1) — Slide 17: store, RBAC (Data Reader), labeled key-values, feature flag
- `demo/python/retrieve_settings.py` — Slide 17-18: `SettingSelector`, labels/composition, `FeatureManager`
- `demo/python/keyvault_reference.py` — Slide 19: Key Vault reference resolved through the same provider
- `demo/scripts/02-seed-webapp-settings` (bash/ps1) — seeds or resets the web app's `TestingApp:DefaultSettings:*` keys and the `xmas` feature flag
- `demo/webapp/` — ASP.NET Core (.NET 8) app showing dynamic refresh with a sentinel key: restart vs. sentinel change, plus a feature flag that refreshes on its own

## Run it

```bash
cd demo/scripts && ./01-create-app-configuration.sh   # or .ps1
cd ../python && pip install azure-appconfiguration-provider azure-identity && python retrieve_settings.py
```

## Dynamic refresh demo (web app)

Requires the .NET 8 SDK or later, and `az login`. The app signs in with Entra ID (no connection string). `01-create-app-configuration` grants you *App Configuration Data Owner*.

```bash
cd demo/scripts
./01-create-app-configuration.sh                 # once - creates the store
./02-seed-webapp-settings.sh                     # before each demo - resets the keys
export APPCONFIG_ENDPOINT="https://appcs-<suffix>.azconfig.io"   # printed by the script
cd ../webapp && dotnet run                       # http://localhost:5200
```

Open the store in the portal (**Operations → Configuration explorer**) next to the app.

The app watches only the sentinel `TestingApp:DefaultSettings:HasChanged`, checking it at most every 10 seconds. The page shows each value it currently has and the time it started.

1. **Without the sentinel, a change needs a restart.** In the portal, change `TestingApp:DefaultSettings:Color` (e.g. `pink`) or `Message`. Reload as often as you like: nothing changes, because the app isn't watching those keys. Stop the app (Ctrl+C), `dotnet run` again, and reload. The new value appears, and "App started" shows the restart.
2. **With the sentinel, no restart.** Change `Color` again (e.g. `orange`), and optionally `Font`/`Message` too. Then change the sentinel's value (`1` → `2`; any different value works). Wait about 10s and reload **twice**: every edited key arrives at once (`refreshAll: true`), with the same "App started" time.
3. **Feature flag (optional).** In **Operations → Feature manager**, turn `xmas` on. The festive banner appears within about 10s (reload twice) without touching the sentinel, because feature flags refresh on their own interval.

Why reload twice: the refresh check runs in the background, triggered by an incoming request. The request that triggers it still renders the old values, and the next one gets the new ones.

Locally, the app leaves managed identity out of its credential chain. On networks that silently drop traffic to the Azure metadata endpoint, probing for managed identity hangs until App Configuration's 100s startup timeout (*"The provider timed out while attempting to load"*), before the `az login` credential is tried.
